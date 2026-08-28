import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { useAuth } from '../auth/AuthContext'
import { LANGS, useLanguage, type Lang } from '../i18n/LanguageContext'
import { useTheme, type ThemeMode } from '../theme/ThemeContext'
import { useVersion } from '../version/VersionContext'
import { exportAll, exportByCategory, exportMonthly } from '../lib/export'

const THEME_OPTIONS: { mode: ThemeMode; labelKey: string }[] = [
  { mode: 'system', labelKey: 'settings.prefs.theme.system' },
  { mode: 'light', labelKey: 'settings.prefs.theme.light' },
  { mode: 'dark', labelKey: 'settings.prefs.theme.dark' },
]

export function Settings() {
  usePageTitle('设置')
  usePageBack(null)

  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const { mode: themeMode, setMode: setThemeMode } = useTheme()
  const { lang, setLang, t } = useLanguage()
  const { version, state: versionState } = useVersion()
  const [exporting, setExporting] = useState<null | 'monthly' | 'category' | 'all'>(null)
  const [exportErr, setExportErr] = useState<string | null>(null)

  function handleLogout() {
    logout()
    navigate('/login')
  }

  async function runExport(kind: 'monthly' | 'category' | 'all'): Promise<void> {
    setExportErr(null)
    setExporting(kind)
    try {
      if (kind === 'monthly') await exportMonthly()
      else if (kind === 'category') await exportByCategory()
      else await exportAll()
    } catch (err) {
      console.error('[export] failed', err)
      setExportErr(err instanceof Error ? err.message : '导出失败')
    } finally {
      setExporting(null)
    }
  }

  const genderText =
    user?.gender === 'male' ? t('settings.userCard.gender.male') :
    user?.gender === 'female' ? t('settings.userCard.gender.female') :
    user?.gender === 'other' ? t('settings.userCard.gender.other') :
    t('settings.userCard.gender.none')
  const ageText = user?.age != null ? String(user.age) : t('settings.userCard.age.none')

  return (
    <div className="space-y-6">
      {/* 标题 */}
      <h2 className="font-headline-md text-headline-md text-on-surface">
        {t('settings.heading')}
      </h2>

      {/* 顶部：用户卡片 + 系统偏好 */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* 用户卡片 — 卡片骨架始终保留；有 user 时显示完整资料；me() 失败时只显示默认头像 + 账号「—」(由 AuthContext 触发全局 toast 提示) */}
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
              {user?.avatar ? (
                <img
                  src={user.avatar}
                  alt="头像"
                  className="w-full h-full object-cover rounded-full"
                />
              ) : (
                <span
                  className="material-symbols-outlined text-white"
                  style={{ fontSize: '56px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
                >
                  person
                </span>
              )}
            </div>
          </div>

          {user ? (
            <>
              <h3 className="font-headline-md text-headline-md text-text-primary mb-1">
                {user.displayName || user.username}
              </h3>
              <p className="font-body-md text-body-md text-on-surface-variant mb-1">
                {t('settings.userCard.accountLabel')}：{user.username}
              </p>
              <p className="font-body-md text-body-md text-on-surface-variant mb-1">
                {t('settings.userCard.freeVersion')}
              </p>
              <p className="font-body-md text-body-md text-on-surface-variant mb-1">
                {t('settings.userCard.genderLabel')}：{genderText}
              </p>
              <p className="font-body-md text-body-md text-on-surface-variant mb-6">
                {t('settings.userCard.ageLabel')}：{ageText}
              </p>

              <Link
                to="/profile/edit"
                className="w-full block text-center py-2.5 px-4 border border-outline text-on-surface font-body-md text-body-md rounded-lg hover:bg-surface-container-low transition-colors"
              >
                {t('settings.userCard.editProfile')}
              </Link>
            </>
          ) : (
            <p className="font-body-md text-body-md text-on-surface-variant">
              {t('settings.userCard.accountLabel')}：—
            </p>
          )}
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
            <h3 className="font-headline-md text-headline-md text-text-primary">
              {t('settings.prefs.title')}
            </h3>
          </div>

          {/* 深色模式 — 3 档 segmented */}
          <div className="flex items-center justify-between pb-6">
            <div>
              <p className="font-headline-md text-headline-md text-text-primary mb-1">
                {t('settings.prefs.theme.label')}
              </p>
              <p className="font-body-md text-body-md text-on-surface-variant">
                {t('settings.prefs.theme.desc')}
              </p>
            </div>
            <div
              role="radiogroup"
              aria-label={t('settings.prefs.theme.label')}
              className="inline-flex p-1 rounded-lg bg-surface-container-low border border-divider"
            >
              {THEME_OPTIONS.map((opt) => {
                const active = themeMode === opt.mode
                return (
                  <button
                    key={opt.mode}
                    type="button"
                    role="radio"
                    aria-checked={active}
                    onClick={() => setThemeMode(opt.mode)}
                    className={
                      'px-3 py-1.5 text-sm rounded-md transition-colors ' +
                      (active
                        ? 'bg-bg-card text-text-primary shadow-sm'
                        : 'text-on-surface-variant hover:text-text-primary')
                    }
                  >
                    {t(opt.labelKey)}
                  </button>
                )
              })}
            </div>
          </div>

          <div className="border-t border-divider" />

          {/* 语言 */}
          <div className="flex items-center justify-between pt-6">
            <div>
              <p className="font-headline-md text-headline-md text-text-primary mb-1">
                {t('settings.prefs.lang.label')}
              </p>
              <p className="font-body-md text-body-md text-on-surface-variant">
                {t('settings.prefs.lang.desc')}
              </p>
            </div>
            <div className="relative">
              <select
                value={lang}
                onChange={(e) => setLang(e.target.value as Lang)}
                className="appearance-none bg-surface-container-low border border-outline rounded-lg pl-5 pr-10 py-2 font-body-md text-body-md text-text-primary hover:border-primary focus:border-primary focus:ring-1 focus:ring-primary transition-colors cursor-pointer"
              >
                {LANGS.map((l) => (
                  <option key={l.code} value={l.code}>
                    {l.label}
                  </option>
                ))}
              </select>
              <span
                className="material-symbols-outlined absolute right-3 top-1/2 -translate-y-1/2 pointer-events-none text-on-surface-variant"
                style={{ fontSize: '20px' }}
              >
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
            disabled={exporting !== null}
            onClick={() => runExport('monthly')}
            className="flex flex-col items-center justify-center gap-3 py-10 px-4 border border-divider rounded-xl bg-surface-container-lowest hover:border-primary hover:bg-primary-light/40 transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:border-divider disabled:hover:bg-surface-container-lowest"
          >
            <span
              className="material-symbols-outlined text-on-surface-variant"
              style={{ fontSize: '36px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
            >
              {exporting === 'monthly' ? 'progress_activity' : 'calendar_month'}
            </span>
            <span className="font-body-md text-body-md text-text-primary">
              {exporting === 'monthly' ? '导出中…' : '导出本月报表'}
            </span>
          </button>

          {/* 按分类导出 */}
          <button
            type="button"
            disabled={exporting !== null}
            onClick={() => runExport('category')}
            className="flex flex-col items-center justify-center gap-3 py-10 px-4 border border-divider rounded-xl bg-surface-container-lowest hover:border-primary hover:bg-primary-light/40 transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:border-divider disabled:hover:bg-surface-container-lowest"
          >
            <span
              className="material-symbols-outlined text-on-surface-variant"
              style={{ fontSize: '36px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
            >
              {exporting === 'category' ? 'progress_activity' : 'category'}
            </span>
            <span className="font-body-md text-body-md text-text-primary">
              {exporting === 'category' ? '导出中…' : '按分类导出'}
            </span>
          </button>

          {/* 导出全部数据 */}
          <button
            type="button"
            disabled={exporting !== null}
            onClick={() => runExport('all')}
            className="flex flex-col items-center justify-center gap-3 py-10 px-4 border border-divider rounded-xl bg-surface-container-lowest hover:border-primary hover:bg-primary-light/40 transition-all disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:border-divider disabled:hover:bg-surface-container-lowest"
          >
            <span
              className="material-symbols-outlined text-on-surface-variant"
              style={{ fontSize: '36px', fontVariationSettings: "'FILL' 0", fontWeight: 300 }}
            >
              {exporting === 'all' ? 'progress_activity' : 'check_circle'}
            </span>
            <span className="font-body-md text-body-md text-text-primary">
              {exporting === 'all' ? '导出中…' : '导出全部数据'}
            </span>
          </button>
        </div>

        <p className="text-center font-body-md text-body-md text-on-surface-variant">
          {exportErr
            ? `导出失败:${exportErr}`
            : '所有数据将以 Excel (.xlsx) 格式导出至您的设备。'}
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
              <p
                className="font-headline-md text-headline-md text-text-primary font-semibold mb-1"
                aria-busy={versionState === 'loading'}
              >
                {versionState === 'loading'
                  ? 'QingZhang v…'
                  : versionState === 'error'
                    ? 'QingZhang v—'
                    : `QingZhang v${version}`}
              </p>
              <p className="font-body-md text-body-md text-on-surface-variant">
                {versionState === 'ok'
                  ? '当前版本'
                  : versionState === 'error'
                    ? '暂不可用,请稍后重试'
                    : '正在获取版本号…'}
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