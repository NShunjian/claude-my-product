import { useState } from 'react'
import { useAuth } from '../auth/AuthContext'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'

export function ProfileEdit() {
  usePageTitle('编辑资料')
  usePageBack('/settings', '设置')

  const { user } = useAuth()

  const [gender, setGender] = useState<'male' | 'female'>('male')
  const [age, setAge] = useState('')
  const [displayName, setDisplayName] = useState(user?.displayName ?? '')
  const [currentPwd, setCurrentPwd] = useState('')
  const [newPwd, setNewPwd] = useState('')
  const [confirmPwd, setConfirmPwd] = useState('')

  // 输入框统一样式
  const inputBase =
    'w-full bg-surface-container-lowest border border-divider rounded-xl pl-12 pr-4 py-3.5 font-body-md text-body-md text-text-primary placeholder:text-outline focus:border-primary focus:ring-1 focus:ring-primary transition-colors'
  const iconWrap =
    'absolute left-4 top-1/2 -translate-y-1/2 material-symbols-outlined text-on-surface-variant pointer-events-none'
  const iconStyle = { fontSize: '20px' }

  return (
    <div className="grid grid-cols-1 md:grid-cols-3 gap-5 items-stretch">
      {/* 修改头像 */}
      <section className="bg-bg-card rounded-2xl border border-divider p-8 shadow-sm flex flex-col">
        <header className="mb-6">
          <h3 className="text-xl font-bold text-text-primary mb-1">修改头像</h3>
          <p className="font-body-md text-body-md text-on-surface-variant">
            更新您的个人资料照片。
          </p>
        </header>

        <div className="flex flex-col items-center gap-5">
          {/* 头像 */}
          <div className="w-36 h-36 rounded-full bg-primary-light flex items-center justify-center">
            <span
              className="material-symbols-outlined text-primary"
              style={{ fontSize: '80px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
            >
              account_circle
            </span>
          </div>

          {/* 上传新头像 */}
          <button
            type="button"
            className="inline-flex items-center gap-2 px-5 py-2.5 border border-outline text-on-surface font-body-md text-body-md rounded-xl hover:bg-surface-container-low hover:border-primary transition-colors"
          >
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '18px' }}
            >
              upload
            </span>
            上传新头像
          </button>
        </div>

        <div className="border-t border-divider mt-auto pt-6">
          <div className="flex justify-end">
            <button
              type="button"
              className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm"
            >
              保存头像
            </button>
          </div>
        </div>
      </section>

      {/* 个人资料 */}
      <section className="bg-bg-card rounded-2xl border border-divider p-8 shadow-sm flex flex-col">
        <header className="mb-6">
          <h3 className="text-xl font-bold text-text-primary mb-1">个人资料</h3>
          <p className="font-body-md text-body-md text-on-surface-variant">
            管理您的基本身份信息。
          </p>
        </header>

        <div className="space-y-6">
          {/* 昵称（可编辑） */}
          <div className="space-y-2">
            <label
              htmlFor="displayName"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              昵称
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>person</span>
              <input
                id="displayName"
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder="请输入昵称"
                className={inputBase}
              />
            </div>
          </div>

          {/* 性别（分段控件） */}
          <div className="space-y-2">
            <span className="block font-headline-md text-headline-md text-text-primary">
              性别
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
                男
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
                女
              </button>
            </div>
          </div>

          {/* 年龄 */}
          <div className="space-y-2">
            <label
              htmlFor="age"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              年龄
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
                placeholder="请输入年龄"
                className={inputBase}
              />
            </div>
          </div>
        </div>

        <div className="border-t border-divider mt-auto pt-6">
          <div className="flex justify-end">
            <button
              type="button"
              className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm"
            >
              保存资料
            </button>
          </div>
        </div>
      </section>

      {/* 安全设置 */}
      <section className="bg-bg-card rounded-2xl border border-divider p-8 shadow-sm flex flex-col">
        <header className="mb-6">
          <h3 className="text-xl font-bold text-text-primary mb-1">安全设置</h3>
          <p className="font-body-md text-body-md text-on-surface-variant">
            更新您的密码以保持账户安全。
          </p>
        </header>

        <div className="space-y-5">
          <div className="space-y-2">
            <label
              htmlFor="currentPwd"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              当前密码
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>lock</span>
              <input
                id="currentPwd"
                type="password"
                value={currentPwd}
                onChange={(e) => setCurrentPwd(e.target.value)}
                placeholder="••••••••"
                className={inputBase}
              />
            </div>
          </div>

          <div className="space-y-2">
            <label
              htmlFor="newPwd"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              新密码
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>key</span>
              <input
                id="newPwd"
                type="password"
                value={newPwd}
                onChange={(e) => setNewPwd(e.target.value)}
                placeholder="至少 8 位字符"
                className={inputBase}
              />
            </div>
          </div>

          <div className="space-y-2">
            <label
              htmlFor="confirmPwd"
              className="block font-headline-md text-headline-md text-text-primary"
            >
              确认新密码
            </label>
            <div className="relative">
              <span className={iconWrap} style={iconStyle}>shield</span>
              <input
                id="confirmPwd"
                type="password"
                value={confirmPwd}
                onChange={(e) => setConfirmPwd(e.target.value)}
                placeholder="再次输入新密码"
                className={inputBase}
              />
            </div>
          </div>
        </div>

        <div className="border-t border-divider mt-auto pt-6">
          <div className="flex justify-end">
            <button
              type="button"
              className="px-6 py-2.5 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container hover:text-on-primary-container transition-colors shadow-sm"
            >
              保存密码
            </button>
          </div>
        </div>
      </section>
    </div>
  )
}