import { useState } from 'react'
import { useAuth } from '../auth/AuthContext'
import { usePageTitle } from '../components/PageTitleContext'

export function ProfileEdit() {
  usePageTitle('编辑资料')
  const { user } = useAuth()

  const [displayName, setDisplayName] = useState<string>(user?.displayName ?? '')
  const [username, setUsername] = useState<string>(user?.username ?? '')
  const [saved, setSaved] = useState<boolean>(false)

  function handleSubmit(e: React.FormEvent<HTMLFormElement>): void {
    e.preventDefault()
    setSaved(true)
    setTimeout(() => setSaved(false), 2000)
  }

  return (
    <div className="space-y-6">
      {/* Breadcrumb back */}
      <div className="flex items-center gap-2 text-on-surface-variant font-body-md text-body-md">
        <a
          href="/settings"
          className="flex items-center gap-1 hover:text-primary transition-colors"
        >
          <span className="material-symbols-outlined text-2xl">chevron_left</span>
          <span>设置</span>
        </a>
        <span className="text-outline">/</span>
        <span className="text-primary font-semibold">编辑资料</span>
      </div>

      {/* Edit form card */}
      <div className="bg-bg-card w-full max-w-2xl rounded-xl border border-divider p-8 shadow-sm">
        <h3 className="font-display-lg text-display-lg text-text-primary mb-8 border-b border-divider pb-4">
          编辑资料
        </h3>

        {/* Avatar section */}
        <section className="p-6 border border-divider rounded-xl bg-surface-container-lowest mb-8">
          <h4 className="font-headline-md text-headline-md text-text-primary mb-6">修改头像</h4>
          <div className="flex flex-col items-center">
            <div className="relative group cursor-pointer mb-4">
              <div className="w-24 h-24 rounded-full bg-primary-light flex items-center justify-center border-4 border-surface-container">
                <span className="material-symbols-outlined text-primary text-4xl" style={{ fontVariationSettings: "'FILL' 1" }}>
                  account_circle
                </span>
              </div>
              <div className="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                <span className="material-symbols-outlined text-white text-2xl drop-shadow-md" style={{ fontVariationSettings: "'FILL' 1" }}>
                  photo_camera
                </span>
              </div>
            </div>
            <button
              type="button"
              className="font-body-md text-body-md text-primary hover:text-primary-container transition-colors mb-6"
            >
              更改头像
            </button>
            <div className="w-full flex justify-end">
              <button
                type="button"
                className="px-6 py-2 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container transition-colors shadow-sm"
              >
                保存头像
              </button>
            </div>
          </div>
        </section>

        {/* Profile info */}
        <form onSubmit={handleSubmit} className="space-y-8">
          <div className="space-y-2">
            <label htmlFor="username" className="block font-headline-md text-headline-md text-on-surface">
              用户名
            </label>
            <input
              id="username"
              type="text"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              className="w-full bg-transparent border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-0 py-2 font-body-md text-body-md text-on-surface placeholder:text-outline transition-colors"
            />
            <p className="font-caption-sm text-caption-sm text-outline">
              用户名用于登录，不可更改
            </p>
          </div>

          <div className="space-y-2">
            <label htmlFor="displayName" className="block font-headline-md text-headline-md text-on-surface">
              显示名称
            </label>
            <input
              id="displayName"
              type="text"
              value={displayName}
              onChange={(e) => setDisplayName(e.target.value)}
              placeholder="设置您的显示名称"
              className="w-full bg-transparent border-0 border-b-2 border-outline-variant focus:border-primary focus:ring-0 px-0 py-2 font-body-md text-body-md text-on-surface placeholder:text-outline transition-colors"
            />
          </div>

          {saved && (
            <div className="flex items-center gap-2 text-secondary font-body-md text-body-md">
              <span className="material-symbols-outlined text-sm" style={{ fontVariationSettings: "'FILL' 1" }}>
                check_circle
              </span>
              保存成功
            </div>
          )}

          <div className="pt-4 border-t border-divider">
            <button
              type="submit"
              className="px-8 py-3 bg-primary text-on-primary font-headline-md text-headline-md rounded-lg hover:bg-primary-container transition-colors shadow-sm"
            >
              保存修改
            </button>
          </div>
        </form>
      </div>
    </div>
  )
}
