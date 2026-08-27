import { useState } from 'react'
import { useAuth } from '../auth/AuthContext'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'

export function ProfileEdit() {
  usePageTitle('编辑资料')
  usePageBack('/settings', '设置')

  const { user } = useAuth()

  const [gender, setGender] = useState<'male' | 'female'>('male')
  const [currentPwd, setCurrentPwd] = useState('')
  const [newPwd, setNewPwd] = useState('')
  const [confirmPwd, setConfirmPwd] = useState('')
  const [savedSection, setSavedSection] = useState<'avatar' | 'profile' | 'password' | null>(null)

  function flashSaved(section: 'avatar' | 'profile' | 'password') {
    setSavedSection(section)
    setTimeout(() => setSavedSection(null), 2000)
  }

  return (
    <div className="space-y-6 max-w-4xl">
      {/* 修改头像 */}
      <section className="bg-bg-card rounded-xl border border-divider p-6 md:p-8 shadow-sm">
        <h3 className="font-headline-md text-headline-md text-text-primary mb-8">修改头像</h3>

        <div className="flex flex-col items-center gap-3">
          {/* 头像 */}
          <div className="w-32 h-32 rounded-full bg-primary-light border-4 border-surface-container-lowest flex items-center justify-center overflow-hidden">
            <span
              className="material-symbols-outlined text-primary"
              style={{ fontSize: '72px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
            >
              account_circle
            </span>
          </div>

          <button
            type="button"
            className="font-body-md text-body-md text-primary hover:text-primary-container hover:underline transition-colors"
          >
            更改头像
          </button>
        </div>

        <div className="flex justify-end items-center gap-3 mt-8">
          {savedSection === 'avatar' && (
            <span className="inline-flex items-center gap-1 text-secondary font-body-md text-body-md">
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '16px', fontVariationSettings: "'FILL' 1" }}
              >
                check_circle
              </span>
              已保存
            </span>
          )}
          <button
            type="button"
            onClick={() => flashSaved('avatar')}
            className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm"
          >
            保存头像
          </button>
        </div>
      </section>

      {/* 修改个人资料 */}
      <section className="bg-bg-card rounded-xl border border-divider p-6 md:p-8 shadow-sm">
        <h3 className="font-headline-md text-headline-md text-text-primary mb-8">修改个人资料</h3>

        <div className="space-y-8">
          {/* 用户名（只读） */}
          <div className="space-y-2">
            <label
              htmlFor="username"
              className="block font-body-md text-body-md text-on-surface"
            >
              用户名
            </label>
            <input
              id="username"
              type="text"
              value={user?.username ?? ''}
              disabled
              className="w-full bg-surface-container-lowest border border-divider rounded-lg px-4 py-3 font-body-md text-body-md text-on-surface placeholder:text-outline cursor-not-allowed"
            />
          </div>

          {/* 性别 */}
          <div className="space-y-3">
            <span className="block font-body-md text-body-md text-on-surface">性别</span>
            <div className="flex items-center gap-8">
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="gender"
                  value="male"
                  checked={gender === 'male'}
                  onChange={() => setGender('male')}
                  className="sr-only peer"
                />
                <span
                  className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
                    gender === 'male'
                      ? 'border-primary'
                      : 'border-outline'
                  }`}
                >
                  {gender === 'male' && (
                    <span className="w-2.5 h-2.5 rounded-full bg-primary" />
                  )}
                </span>
                <span className="font-body-md text-body-md text-text-primary">男</span>
              </label>
              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="radio"
                  name="gender"
                  value="female"
                  checked={gender === 'female'}
                  onChange={() => setGender('female')}
                  className="sr-only peer"
                />
                <span
                  className={`w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors ${
                    gender === 'female'
                      ? 'border-primary'
                      : 'border-outline'
                  }`}
                >
                  {gender === 'female' && (
                    <span className="w-2.5 h-2.5 rounded-full bg-primary" />
                  )}
                </span>
                <span className="font-body-md text-body-md text-text-primary">女</span>
              </label>
            </div>
          </div>
        </div>

        <div className="flex justify-end items-center gap-3 mt-8">
          {savedSection === 'profile' && (
            <span className="inline-flex items-center gap-1 text-secondary font-body-md text-body-md">
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '16px', fontVariationSettings: "'FILL' 1" }}
              >
                check_circle
              </span>
              已保存
            </span>
          )}
          <button
            type="button"
            onClick={() => flashSaved('profile')}
            className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm"
          >
            保存资料
          </button>
        </div>
      </section>

      {/* 修改密码 */}
      <section className="bg-bg-card rounded-xl border border-divider p-6 md:p-8 shadow-sm">
        <h3 className="font-headline-md text-headline-md text-text-primary mb-8">修改密码</h3>

        <div className="space-y-6">
          <div className="space-y-2">
            <label
              htmlFor="currentPwd"
              className="block font-body-md text-body-md text-on-surface"
            >
              当前密码
            </label>
            <input
              id="currentPwd"
              type="password"
              value={currentPwd}
              onChange={(e) => setCurrentPwd(e.target.value)}
              placeholder="••••••••"
              className="w-full bg-surface-container-lowest border border-divider rounded-lg px-4 py-3 font-body-md text-body-md text-on-surface placeholder:text-outline focus:border-primary focus:ring-1 focus:ring-primary transition-colors"
            />
          </div>

          <div className="space-y-2">
            <label
              htmlFor="newPwd"
              className="block font-body-md text-body-md text-on-surface"
            >
              新密码
            </label>
            <input
              id="newPwd"
              type="password"
              value={newPwd}
              onChange={(e) => setNewPwd(e.target.value)}
              placeholder="至少 8 位字符"
              className="w-full bg-surface-container-lowest border border-divider rounded-lg px-4 py-3 font-body-md text-body-md text-on-surface placeholder:text-outline focus:border-primary focus:ring-1 focus:ring-primary transition-colors"
            />
          </div>

          <div className="space-y-2">
            <label
              htmlFor="confirmPwd"
              className="block font-body-md text-body-md text-on-surface"
            >
              确认新密码
            </label>
            <input
              id="confirmPwd"
              type="password"
              value={confirmPwd}
              onChange={(e) => setConfirmPwd(e.target.value)}
              placeholder="再次输入新密码"
              className="w-full bg-surface-container-lowest border border-divider rounded-lg px-4 py-3 font-body-md text-body-md text-on-surface placeholder:text-outline focus:border-primary focus:ring-1 focus:ring-primary transition-colors"
            />
          </div>
        </div>

        <div className="flex justify-end items-center gap-3 mt-8">
          {savedSection === 'password' && (
            <span className="inline-flex items-center gap-1 text-secondary font-body-md text-body-md">
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '16px', fontVariationSettings: "'FILL' 1" }}
              >
                check_circle
              </span>
              已保存
            </span>
          )}
          <button
            type="button"
            onClick={() => flashSaved('password')}
            className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm"
          >
            保存密码
          </button>
        </div>
      </section>
    </div>
  )
}