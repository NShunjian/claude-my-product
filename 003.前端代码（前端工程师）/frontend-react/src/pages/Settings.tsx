import { usePageTitle, usePageBack } from '../components/PageTitleContext'

export function Settings() {
  usePageTitle('设置')
  usePageBack(null)

  return (
    <div className="space-y-6">
      <div>
        <h2 className="font-display-lg text-display-lg text-on-surface mb-6">设置</h2>
      </div>

      {/* Settings sections */}
      <div className="bg-bg-card rounded-xl border border-divider overflow-hidden shadow-sm">
        {/* Account section */}
        <div className="p-4 border-b border-divider">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">账户</h3>
          <div className="space-y-1">
            <a
              href="/profile/edit"
              className="flex items-center justify-between py-3 px-2 hover:bg-surface-container transition-colors rounded-lg -mx-2"
            >
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  person
                </span>
                <span className="font-body-md text-body-md text-text-primary">编辑资料</span>
              </div>
              <span className="material-symbols-outlined text-on-surface-variant text-xl">
                chevron_right
              </span>
            </a>
            <div className="flex items-center justify-between py-3 px-2">
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  lock
                </span>
                <span className="font-body-md text-body-md text-text-primary">修改密码</span>
              </div>
              <span className="material-symbols-outlined text-on-surface-variant text-xl">
                chevron_right
              </span>
            </div>
          </div>
        </div>

        {/* Preferences section */}
        <div className="p-4 border-b border-divider">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">偏好设置</h3>
          <div className="space-y-1">
            <div className="flex items-center justify-between py-3 px-2">
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  language
                </span>
                <span className="font-body-md text-body-md text-text-primary">货币</span>
              </div>
              <span className="font-body-md text-body-md text-on-surface-variant">CNY ¥</span>
            </div>
            <div className="flex items-center justify-between py-3 px-2">
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  calendar_month
                </span>
                <span className="font-body-md text-body-md text-text-primary">日期格式</span>
              </div>
              <span className="font-body-md text-body-md text-on-surface-variant">YYYY-MM-DD</span>
            </div>
          </div>
        </div>

        {/* Notifications section */}
        <div className="p-4 border-b border-divider">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">通知</h3>
          <div className="space-y-1">
            <div className="flex items-center justify-between py-3 px-2">
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  notifications
                </span>
                <span className="font-body-md text-body-md text-text-primary">推送通知</span>
              </div>
              <div className="relative inline-block w-11 h-6 cursor-pointer">
                <input id="toggle-notif" type="checkbox" className="sr-only peer" defaultChecked />
                <label
                  htmlFor="toggle-notif"
                  className="block w-11 h-6 bg-outline rounded-full cursor-pointer transition-colors peer-checked:bg-primary"
                >
                  <span className="absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform peer-checked:translate-x-5" />
                </label>
              </div>
            </div>
            <div className="flex items-center justify-between py-3 px-2">
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  mail
                </span>
                <span className="font-body-md text-body-md text-text-primary">邮件提醒</span>
              </div>
              <div className="relative inline-block w-11 h-6 cursor-pointer">
                <input id="toggle-email" type="checkbox" className="sr-only peer" />
                <label
                  htmlFor="toggle-email"
                  className="block w-11 h-6 bg-outline rounded-full cursor-pointer transition-colors peer-checked:bg-primary"
                >
                  <span className="absolute left-0.5 top-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform peer-checked:translate-x-5" />
                </label>
              </div>
            </div>
          </div>
        </div>

        {/* About section */}
        <div className="p-4">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">关于</h3>
          <div className="space-y-1">
            <div className="flex items-center justify-between py-3 px-2">
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  info
                </span>
                <span className="font-body-md text-body-md text-text-primary">版本</span>
              </div>
              <span className="font-body-md text-body-md text-on-surface-variant">v1.0.0</span>
            </div>
            <div className="flex items-center justify-between py-3 px-2">
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  description
                </span>
                <span className="font-body-md text-body-md text-text-primary">服务条款</span>
              </div>
              <span className="material-symbols-outlined text-on-surface-variant text-xl">
                open_in_new
              </span>
            </div>
            <div className="flex items-center justify-between py-3 px-2">
              <div className="flex items-center gap-3">
                <span className="material-symbols-outlined text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                  privacy_tip
                </span>
                <span className="font-body-md text-body-md text-text-primary">隐私政策</span>
              </div>
              <span className="material-symbols-outlined text-on-surface-variant text-xl">
                open_in_new
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}
