import { useEffect, useRef, useState } from 'react'
import { useAuth } from '../auth/AuthContext'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { useLanguage } from '../i18n/LanguageContext'
import * as usersApi from '../api/users'
import type { Gender } from '../api/users'

export function ProfileEdit() {
  const { t } = useLanguage()
  usePageTitle(t('pageTitle.profileEdit'))
  usePageBack('/settings', t('pageTitle.settings'))

  const { user, refreshUser } = useAuth()

  const [gender, setGender] = useState<Gender | ''>('')
  const [age, setAge] = useState('')
  const [displayName, setDisplayName] = useState(user?.displayName ?? '')

  const [currentPwd, setCurrentPwd] = useState('')
  const [newPwd, setNewPwd] = useState('')
  const [confirmPwd, setConfirmPwd] = useState('')

  const [savingProfile, setSavingProfile] = useState(false)
  const [savingPwd, setSavingPwd] = useState(false)
  const [savingAvatar, setSavingAvatar] = useState(false)
  const [profileMsg, setProfileMsg] = useState<{ kind: 'ok' | 'err'; text: string } | null>(null)
  const [pwdMsg, setPwdMsg] = useState<{ kind: 'ok' | 'err'; text: string } | null>(null)
  const [avatarMsg, setAvatarMsg] = useState<{ kind: 'ok' | 'err'; text: string } | null>(null)

  // 头像本地预览（待保存的压缩图），保存成功后再 refreshUser() 让 user.avatar 同步
  const [avatarPreview, setAvatarPreview] = useState<string | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // user 进入/变更时同步本地 state（特别是保存成功后 refreshUser() 会触发）
  useEffect(() => {
    setDisplayName(user?.displayName ?? '')
    setGender((user?.gender as Gender | undefined) ?? '')
    setAge(user?.age != null ? String(user.age) : '')
  }, [user])

  async function handleSaveProfile(): Promise<void> {
    setProfileMsg(null)
    const trimmedName = displayName.trim()
    if (trimmedName.length === 0) {
      setProfileMsg({ kind: 'err', text: t('profileEdit.nameRequired') })
      return
    }
    const parsedAge = age.trim() === '' ? null : Number.parseInt(age, 10)
    if (parsedAge !== null && (!Number.isFinite(parsedAge) || parsedAge < 0 || parsedAge > 150)) {
      setProfileMsg({ kind: 'err', text: t('profileEdit.ageInvalid') })
      return
    }
    setSavingProfile(true)
    try {
      await usersApi.updateProfile({
        displayName: trimmedName,
        gender: gender === '' ? null : gender,
        age: parsedAge,
      })
      await refreshUser()
      setProfileMsg({ kind: 'ok', text: t('profileEdit.profileSaved') })
    } catch (err) {
      const text = err instanceof Error ? err.message : t('profileEdit.saveFailDefault')
      setProfileMsg({ kind: 'err', text })
    } finally {
      setSavingProfile(false)
    }
  }

  async function handleChangePassword(): Promise<void> {
    setPwdMsg(null)
    if (currentPwd.length === 0 || newPwd.length === 0 || confirmPwd.length === 0) {
      setPwdMsg({ kind: 'err', text: t('profileEdit.passwordFillAll') })
      return
    }
    if (newPwd !== confirmPwd) {
      setPwdMsg({ kind: 'err', text: t('profileEdit.passwordMismatch') })
      return
    }
    if (newPwd.length < 8) {
      setPwdMsg({ kind: 'err', text: t('profileEdit.passwordTooShort') })
      return
    }
    if (newPwd === currentPwd) {
      setPwdMsg({ kind: 'err', text: t('profileEdit.passwordSame') })
      return
    }
    setSavingPwd(true)
    try {
      await usersApi.changePassword({ oldPassword: currentPwd, newPassword: newPwd })
      setCurrentPwd('')
      setNewPwd('')
      setConfirmPwd('')
      setPwdMsg({ kind: 'ok', text: t('profileEdit.passwordChanged') })
    } catch (err) {
      const text = err instanceof Error ? err.message : t('profileEdit.passwordChangeFailDefault')
      setPwdMsg({ kind: 'err', text })
    } finally {
      setSavingPwd(false)
    }
  }

  /** 把 File 缩放到 128×128 JPEG(0.85)，输出 base64 dataURL。失败抛错。 */
  function compressAvatar(file: File): Promise<string> {
    return new Promise((resolve, reject) => {
      if (!file.type.startsWith('image/')) {
        reject(new Error(t('profileEdit.avatarInvalidType')))
        return
      }
      const reader = new FileReader()
      reader.onerror = () => reject(new Error(t('profileEdit.avatarReadFail')))
      reader.onload = () => {
        const img = new Image()
        img.onerror = () => reject(new Error(t('profileEdit.avatarParseFail')))
        img.onload = () => {
          const canvas = document.createElement('canvas')
          const MAX = 128
          const ratio = Math.min(MAX / img.width, MAX / img.height, 1)
          canvas.width = Math.max(1, Math.round(img.width * ratio))
          canvas.height = Math.max(1, Math.round(img.height * ratio))
          const ctx = canvas.getContext('2d')
          if (!ctx) {
            reject(new Error(t('profileEdit.avatarCanvasFail')))
            return
          }
          ctx.drawImage(img, 0, 0, canvas.width, canvas.height)
          resolve(canvas.toDataURL('image/jpeg', 0.85))
        }
        img.src = String(reader.result)
      }
      reader.readAsDataURL(file)
    })
  }

  async function handleAvatarFileChange(e: React.ChangeEvent<HTMLInputElement>): Promise<void> {
    setAvatarMsg(null)
    const file = e.target.files?.[0]
    // 复位 input value 以便选同一文件能再次触发 onChange
    e.target.value = ''
    if (!file) return
    try {
      const dataUrl = await compressAvatar(file)
      setAvatarPreview(dataUrl)
      setAvatarMsg({ kind: 'ok', text: t('profileEdit.avatarPreviewReady') })
    } catch (err) {
      const text = err instanceof Error ? err.message : t('profileEdit.avatarProcessFailDefault')
      setAvatarMsg({ kind: 'err', text })
    }
  }

  async function handleSaveAvatar(): Promise<void> {
    setAvatarMsg(null)
    if (!avatarPreview) {
      setAvatarMsg({ kind: 'err', text: t('profileEdit.avatarSelectFile') })
      return
    }
    setSavingAvatar(true)
    try {
      await usersApi.updateProfile({ avatar: avatarPreview })
      await refreshUser()
      setAvatarPreview(null)
      setAvatarMsg({ kind: 'ok', text: t('profileEdit.avatarUpdated') })
    } catch (err) {
      const text = err instanceof Error ? err.message : t('profileEdit.saveFailDefault')
      setAvatarMsg({ kind: 'err', text })
    } finally {
      setSavingAvatar(false)
    }
  }

  // 输入框统一样式
  const inputBase =
    'w-full bg-surface-container-lowest border border-divider rounded-xl pl-12 pr-4 py-3.5 font-body-md text-body-md text-text-primary placeholder:text-outline focus:border-primary focus:ring-1 focus:ring-primary transition-colors'
  const iconWrap =
    'absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-on-surface-variant pointer-events-none'
  const iconStyle = { fontSize: '20px' }
  const spinner = (
    <span
      className="material-symbols-outlined animate-spin"
      style={{ fontSize: '18px' }}
    >
      progress_activity
    </span>
  )

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-5 items-stretch">
      {/* 修改头像 */}
      <section className="bg-bg-card rounded-2xl border border-divider p-8 shadow-sm flex flex-col">
        <header className="mb-6">
          <h3 className="text-xl font-bold text-text-primary mb-1">{t('profileEdit.avatarSection')}</h3>
          <p className="font-body-md text-body-md text-on-surface-variant">
            {t('profileEdit.avatarDesc')}
          </p>
        </header>

        <div className="flex flex-col items-center gap-5">
          <div className="w-36 h-36 rounded-full bg-primary-light flex items-center justify-center overflow-hidden">
            {avatarPreview || user?.avatar ? (
              <img
                src={avatarPreview ?? user!.avatar!}
                alt={t('profileEdit.avatarAlt')}
                className="w-full h-full object-cover"
              />
            ) : (
              <span
                className="material-symbols-outlined text-primary"
                style={{ fontSize: '80px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
              >
                account_circle
              </span>
            )}
          </div>

          <button
            type="button"
            onClick={() => fileInputRef.current?.click()}
            className="inline-flex items-center gap-2 px-5 py-2.5 border border-outline text-on-surface font-body-md text-body-md rounded-xl hover:bg-surface-container-low hover:border-primary transition-colors"
          >
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '18px' }}
            >
              upload
            </span>
            {t('profileEdit.uploadAvatar')}
          </button>
          <input
            ref={fileInputRef}
            type="file"
            accept="image/png,image/jpeg,image/webp"
            className="hidden"
            onChange={handleAvatarFileChange}
          />

          {avatarMsg && (
            <div
              className={`w-full rounded-lg px-3 py-2 font-caption-sm text-caption-sm ${
                avatarMsg.kind === 'ok'
                  ? 'bg-secondary-container text-on-secondary-container'
                  : 'bg-error-container text-on-error-container'
              }`}
            >
              {avatarMsg.text}
            </div>
          )}
        </div>

        <div className="border-t border-divider mt-auto pt-6">
          <div className="flex justify-end">
            <button
              type="button"
              onClick={handleSaveAvatar}
              disabled={savingAvatar || !avatarPreview}
              className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm disabled:opacity-60 disabled:cursor-not-allowed inline-flex items-center gap-2"
            >
              {savingAvatar && spinner}
              {t('profileEdit.saveAvatar')}
            </button>
          </div>
        </div>
      </section>

      {/* 个人资料 */}
      <section className="bg-bg-card rounded-2xl border border-divider p-8 shadow-sm flex flex-col">
        <header className="mb-6">
          <h3 className="text-xl font-bold text-text-primary mb-1">{t('profileEdit.profileSection')}</h3>
          <p className="font-body-md text-body-md text-on-surface-variant">
            {t('profileEdit.profileDesc')}
          </p>
        </header>

        <div className="space-y-6">
          {/* 昵称（可编辑） */}
          <div className="space-y-2">
            <label
              htmlFor="displayName"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              {t('profileEdit.displayName')}
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>person</span>
              <input
                id="displayName"
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder={t('profileEdit.displayNamePlaceholder')}
                className={inputBase}
              />
            </div>
          </div>

          {/* 性别（分段控件） */}
          <div className="space-y-2">
            <span className="block font-headline-md text-headline-md text-text-primary">
              {t('profileEdit.gender')}
            </span>
            <div className="grid grid-cols-2 gap-4">
              <button
                type="button"
                onClick={() => setGender('male')}
                className={`flex items-center justify-center gap-3 py-4 rounded-xl font-body-md text-body-md transition-colors ${
                  gender === 'male'
                    ? 'border-2 border-primary bg-primary-light/40 text-primary font-semibold'
                    : 'border border-divider bg-surface-container-lowest text-on-surface hover:border-primary'
                }`}
              >
                <span
                  className="material-symbols-outlined"
                  style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
                >
                  male
                </span>
                {t('profileEdit.gender.male')}
              </button>
              <button
                type="button"
                onClick={() => setGender('female')}
                className={`flex items-center justify-center gap-3 py-4 rounded-xl font-body-md text-body-md transition-colors ${
                  gender === 'female'
                    ? 'border-2 border-primary bg-primary-light/40 text-primary font-semibold'
                    : 'border border-divider bg-surface-container-lowest text-on-surface hover:border-primary'
                }`}
              >
                <span
                  className="material-symbols-outlined"
                  style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
                >
                  female
                </span>
                {t('profileEdit.gender.female')}
              </button>
            </div>
          </div>

          {/* 年龄 */}
          <div className="space-y-2">
            <label
              htmlFor="age"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              {t('profileEdit.age')}
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>calendar_month</span>
              <input
                id="age"
                type="number"
                min={0}
                max={150}
                value={age}
                onChange={(e) => setAge(e.target.value)}
                placeholder={t('profileEdit.agePlaceholder')}
                className={inputBase}
              />
            </div>
          </div>
        </div>

        {profileMsg && (
          <div
            className={`mt-4 rounded-lg px-3 py-2 font-caption-sm text-caption-sm ${
              profileMsg.kind === 'ok'
                ? 'bg-secondary-container text-on-secondary-container'
                : 'bg-error-container text-on-error-container'
            }`}
          >
            {profileMsg.text}
          </div>
        )}

        <div className="border-t border-divider mt-auto pt-6">
          <div className="flex justify-end">
            <button
              type="button"
              onClick={handleSaveProfile}
              disabled={savingProfile}
              className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm disabled:opacity-60 disabled:cursor-not-allowed inline-flex items-center gap-2"
            >
              {savingProfile && spinner}
              {t('profileEdit.saveProfile')}
            </button>
          </div>
        </div>
      </section>

      {/* 安全设置 */}
      <section className="bg-bg-card rounded-2xl border border-divider p-8 shadow-sm flex flex-col">
        <header className="mb-6">
          <h3 className="text-xl font-bold text-text-primary mb-1">{t('profileEdit.securitySection')}</h3>
          <p className="font-body-md text-body-md text-on-surface-variant">
            {t('profileEdit.securityDesc')}
          </p>
        </header>

        <div className="space-y-5">
          <div className="space-y-2">
            <label
              htmlFor="currentPwd"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              {t('profileEdit.oldPassword')}
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>lock</span>
              <input
                id="currentPwd"
                type="password"
                value={currentPwd}
                onChange={(e) => setCurrentPwd(e.target.value)}
                placeholder={t('profileEdit.oldPasswordPlaceholder')}
                className={inputBase}
              />
            </div>
          </div>

          <div className="space-y-2">
            <label
              htmlFor="newPwd"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              {t('profileEdit.newPassword')}
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>key</span>
              <input
                id="newPwd"
                type="password"
                value={newPwd}
                onChange={(e) => setNewPwd(e.target.value)}
                placeholder={t('profileEdit.newPasswordPlaceholder')}
                className={inputBase}
              />
            </div>
          </div>

          <div className="space-y-2">
            <label
              htmlFor="confirmPwd"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              {t('profileEdit.confirmPassword')}
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>shield</span>
              <input
                id="confirmPwd"
                type="password"
                value={confirmPwd}
                onChange={(e) => setConfirmPwd(e.target.value)}
                placeholder={t('profileEdit.confirmPasswordPlaceholder')}
                className={inputBase}
              />
            </div>
          </div>
        </div>

        {pwdMsg && (
          <div
            className={`mt-4 rounded-lg px-3 py-2 font-caption-sm text-caption-sm ${
              pwdMsg.kind === 'ok'
                ? 'bg-secondary-container text-on-secondary-container'
                : 'bg-error-container text-on-error-container'
            }`}
          >
            {pwdMsg.text}
          </div>
        )}

        <div className="border-t border-divider mt-auto pt-6">
          <div className="flex justify-end">
            <button
              type="button"
              onClick={handleChangePassword}
              disabled={savingPwd}
              className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm disabled:opacity-60 disabled:cursor-not-allowed inline-flex items-center gap-2"
            >
              {savingPwd && spinner}
              {t('profileEdit.savePassword')}
            </button>
          </div>
        </div>
      </section>
    </div>
  )
}
