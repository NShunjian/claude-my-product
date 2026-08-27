import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { useAuth } from '../auth/AuthContext'

export function Settings() {
  usePageTitle('设置')
  usePageBack(null)

  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const [darkMode, setDarkMode] = useState(false)
  const [language, setLanguage] = useState('简体中文')

  function handleLogout() {
    logout()
    navigate('/login')
  }

  return (
    <div className="space-y-6">
      {/* 标题 */}
      <h2 className="font-headline-md text-headline-md text-on-surface">
        管理您的账户偏好与系统设置
      </h2>

      {/* 顶部：用户卡片 + 系统偏好 */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* 用户卡片 */}
        <div className="bento-item bg-bg-card lg:col-span-4 flex flex-col items-center text-center p-8">
          {/* 头像 + 设置·轻账 弧形文字 */}
          <div className="relative w-32 h-32 mb-4">
            <svg viewBox="0 0 120 120" className="absolute inset-0 w-full h-full">
              <defs>
                <path
                  id="circlePath"
                  d="M 60,60 m -48,0 a 48,48 0 1,1 96,0 a 48,48 0 1,1 -96,0"
                />
              </defs>
              <text
                fill="#414750"
                fontSize="9"
                letterSpacing="3"
                style={{ fontFamily: 'Inter, system-ui, sans-serif' }}
              >
                <textPath href="#circlePath" startOffset="0%">
                  设置 · 轻账 ·
                </textPath>
              </text>
            </svg>
            <div className="absolute inset-3 rounded-full bg-gradient-to-br from-primary-light to-primary flex items-center justify-center overflow-hidden">
              <span
                className="material-symbols-outlined text-white"
                style={{ fontSize: '56px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
              >
                person
              </span>
            </div>
          </div>

          <h3 className="font-headline-md text-headline-md text-text-primary mb-1">
            {user?.displayName || user?.username || 'testuser'}
          </h3>
          <p className="font-body-md text-body-md text-on-surface-variant mb-1">
            账号：{user?.username || 'demo'}
          </p>
          <p className="font-body-md text-body-md text-on-surface-variant mb-1">免费版用户</p>
          <p className="font-body-md text-body-md text-on-surface-variant mb-1">
            性别：男
          </p>
          <p className="font-body-md text-body-md text-on-surface-variant mb-6">
            年龄：25
          </p>

          <Link
            to="/profile/edit"
            className="w-full block text-center py-2.5 px-4 border border-outline text-on-surface font-body-md text-body-md rounded-lg hover:bg-surface-container-low transition-colors"
          >
            编辑资料
          </Link>
        </div>

        {/* 系统偏好 */}
        <div className="bento-item bg-bg-card lg:col-span-8 p-8">
          <div className="flex items-center gap-3 mb-8">
            <span
              className="w-9 h-9 rounded-full flex items-center justify-center bg-primary-light text-primary"
            >
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
              >
                tune
              </span>
            </span>
            <h3 className="font-headline-md text-headline-md text-text-primary">系统偏好</h3>
          </div>

          {/* 深色模式 */}
          <div className="flex items-center justify-between pb-6">
            <div>
              <p className="font-headline-md text-headline-md text-text-primary mb-1">深色模式</p>
              <p className="font-body-md text-body-md text-on-surface-variant">
                跟随系统或手动切换
              </p>
            </div>
            <label className="relative inline-flex items-center cursor-pointer">
              <input
                type="checkbox"
                className="sr-only peer"
                checked={darkMode}
                onChange={(e) => setDarkMode(e.target.checked)}
              />
              <div className="w-12 h-7 bg-outline-variant rounded-full peer peer-checked:bg-primary peer-focus:outline-none after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-6 after:w-6 after:transition-all peer-checked:after:translate-x-5" />
            </label>
          </div>

          <div className="border-t border-divider" />

          {/* 语言 */}
          <div className="flex items-center justify-between pt-6">
            <div>
              <p className="font-headline-md text-headline-md text-text-primary mb-1">
                语言 / Language
              </p>
              <p className="font-body-md text-body-md text-on-surface-variant">
                选择应用显示语言
              </p>
            </div>
            <div className="relative">
              <select
                value={language}
                onChange={(e) => setLanguage(e.target.value)}
                className="appearance-none bg-surface-container-low border border-outline rounded-lg pl-5 pr-10 py-2 font-body-md text-body-md text-text-primary hover:border-primary focus:border-primary focus:ring-1 focus:ring-primary transition-colors cursor-pointer"
              >
                <option value="简体中文">简体中文</option>
                <option value="English">English</option>
                <option value="繁體中文">繁體中文</option>
              </select>
              <span className="material-symbols-outlined absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none text-on-surface-variant" style={{ fontSize: '20px' }}>
                expand_more
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* 中部：数据管理 */}
      <div className="bento-item bg-bg-card p-8">
        <div className="flex items-center gap-3 mb-8">
          <span
            className="w-9 h-9 rounded-full flex items-center justify-center bg-primary-light text-primary"
          >
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
            >
              database
            </span>
          </span>
          <h3 className="font-headline-md text-headline-md text-text-primary">数据管理</h3>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
          {/* 导出本月报表 */}
          <button
            type="button"
            className="flex flex-col items-center justify-center gap-3 py-10 px-4 border border-divider rounded-xl bg-surface-container-lowest hover:border-primary hover:bg-primary-light/40 transition-all"
          >
            <span
              className="material-symbols-outlined text-on-surface-variant"
              style={{ fontSize: '36px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
            >
              calendar_month
            </span>
            <span className="font-body-md text-body-md text-text-primary">导出本月报表</span>
          </button>

          {/* 按分类导出 */}
          <button
            type="button"
            className="flex flex-col items-center justify-center gap-3 py-10 px-4 border border-divider rounded-xl bg-surface-container-lowest hover:border-primary hover:bg-primary-light/40 transition-all"
          >
            <span
              className="material-symbols-outlined text-on-surface-variant"
              style={{ fontSize: '36px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
            >
              category
            </span>
            <span className="font-body-md text-body-md text-text-primary">按分类导出</span>
          </button>

          {/* 导出全部数据 */}
          <button
            type="button"
            className="flex flex-col items-center justify-center gap-3 py-10 px-4 border border-divider rounded-xl bg-surface-container-lowest hover:border-primary hover:bg-primary-light/40 transition-all"
          >
            <span
              className="material-symbols-outlined text-on-surface-variant"
              style={{ fontSize: '36px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
            >
              check_circle
            </span>
            <span className="font-body-md text-body-md text-text-primary">导出全部数据</span>
          </button>
        </div>

        <p className="text-center font-body-md text-body-md text-on-surface-variant">
          所有数据将以 Excel (.xlsx) 格式导出至您的设备。
        </p>
      </div>

      {/* 底部：关于轻账 + 账号安全 */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* 关于轻账 */}
        <div className="bento-item bg-bg-card lg:col-span-7 p-8">
          <div className="flex items-center gap-3 mb-8">
            <span
              className="material-symbols-outlined text-primary"
              style={{ fontSize: '22px', fontVariationSettings: "'FILL' 1" }}
            >
              info
            </span>
            <h3 className="font-headline-md text-headline-md text-text-primary">关于轻账</h3>
          </div>

          <div className="flex items-start gap-4 mb-8">
            <div className="w-14 h-16 rounded-lg bg-primary-light flex items-center justify-center flex-shrink-0">
              <span className="font-display-lg text-display-lg text-primary font-bold">
                Q
              </span>
            </div>
            <div>
              <p className="font-headline-md text-headline-md text-text-primary font-semibold mb-1">
                QingZhang v2.4.1
              </p>
              <p className="font-body-md text-body-md text-on-surface-variant">
                最新版本已更新
              </p>
            </div>
          </div>

          <div className="flex items-center gap-6 pt-4 border-t border-divider">
            <a
              href="#"
              className="font-body-md text-body-md text-primary hover:underline"
            >
              服务条款
            </a>
            <a
              href="#"
              className="font-body-md text-body-md text-primary hover:underline"
            >
              隐私政策
            </a>
          </div>
        </div>

        {/* 账号安全 */}
        <div className="bento-item bg-bg-card lg:col-span-5 p-8 flex flex-col">
          <div className="flex items-center gap-3 mb-6">
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '22px', color: '#ba1a1a', fontVariationSettings: "'FILL' 1" }}
            >
              shield
            </span>
            <h3 className="font-headline-md text-headline-md text-text-primary">账号安全</h3>
          </div>

          <p className="font-body-md text-body-md text-on-surface-variant mb-8 leading-relaxed">
            退出登录后，需要重新输入密码或使用生物识别认证才能再次访问您的账单数据。
          </p>

          <div className="mt-auto flex justify-end">
            <button
              type="button"
              onClick={handleLogout}
              className="inline-flex items-center gap-2 px-5 py-2.5 border-2 border-error text-error font-body-md text-body-md rounded-lg hover:bg-error hover:text-white transition-colors"
            >
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '18px', fontVariationSettings: "'FILL' 1" }}
              >
                logout
              </span>
              退出登录
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}