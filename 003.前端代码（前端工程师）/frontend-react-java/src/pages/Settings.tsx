import { useState } from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { useAuth } from '../auth/AuthContext'
import { LANGS, useLanguage, type Lang } from '../i18n/LanguageContext'
import { useTheme, type ThemeMode } from '../theme/ThemeContext'
import { useVersion } from '../version/VersionContext'
import { exportAll, exportByCategory, exportMonthly } from '../lib/export'
import * as categoriesApi from '../api/categories'
import type { Category, CategoryType } from '../api/categories'
import { useCategories } from '../lib/hooks'
import { useToast } from '../components/Toast'
import { ApiError } from '../lib/api'

const THEME_OPTIONS: { mode: ThemeMode; labelKey: string }[] = [
  { mode: 'system', labelKey: 'settings.prefs.theme.system' },
  { mode: 'light', labelKey: 'settings.prefs.theme.light' },
  { mode: 'dark', labelKey: 'settings.prefs.theme.dark' },
]

export function Settings() {
  const { user, logout } = useAuth()
  const navigate = useNavigate()
  const { mode: themeMode, setMode: setThemeMode } = useTheme()
  const { lang, setLang, t } = useLanguage()
  const { version, state: versionState } = useVersion()
  const [exporting, setExporting] = useState<null | 'monthly' | 'category' | 'all'>(null)
  const [exportErr, setExportErr] = useState<string | null>(null)

  usePageTitle(t('pageTitle.settings'))
  usePageBack(null)

  function handleLogout() {
    void logout()  // fire-and-forget:调后端 /api/auth/logout + 清本地 token
    navigate('/login', { replace: true })  // replace 避免后退回到 /settings 再被 ProtectedRoute 踢出
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
      setExportErr(err instanceof Error ? err.message : t('settings.data.exportFailPrefix'))
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
                  {t('settings.about.title')}
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

      {/* 中部:分类管理(用户级全局自定义分类) */}
      <CategoriesSection />

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
          <h3 className="font-headline-md text-headline-md text-text-primary">{t('settings.data.title')}</h3>
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
              {exporting === 'monthly' ? t('settings.data.exporting') : t('settings.data.exportMonthly')}
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
              {exporting === 'category' ? t('settings.data.exporting') : t('settings.data.exportCategory')}
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
              {exporting === 'all' ? t('settings.data.exporting') : t('settings.data.exportAll')}
            </span>
          </button>
        </div>

        <p className="text-center font-body-md text-body-md text-on-surface-variant">
          {exportErr
            ? `${t('settings.data.exportFailPrefix')}${exportErr}`
            : t('settings.data.exportDesc')}
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
            <h3 className="font-headline-md text-headline-md text-text-primary">{t('settings.about.title')}</h3>
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
                  ? t('settings.about.currentVersion')
                  : versionState === 'error'
                    ? t('settings.about.versionUnavailable')
                    : t('settings.about.fetchingVersion')}
              </p>
            </div>
          </div>

          <div className="flex items-center gap-6 pt-4 border-t border-divider">
            <a
              href="#"
              className="font-body-md text-body-md text-primary hover:underline"
            >
              {t('settings.about.terms')}
            </a>
            <a
              href="#"
              className="font-body-md text-body-md text-primary hover:underline"
            >
              {t('settings.about.privacy')}
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
            <h3 className="font-headline-md text-headline-md text-text-primary">{t('settings.accountSecurity.title')}</h3>
          </div>

          <p className="font-body-md text-body-md text-on-surface-variant mb-8 leading-relaxed">
            {t('settings.accountSecurity.desc')}
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
              {t('settings.accountSecurity.logout')}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

/**
 * 自定义分类管理(V1.1):
 *   - 用户级全局,跨账本可见
 *   - 预设(is_preset=1)只读,只列出来参考
 *   - 自定义可新增/重命名/改 icon 颜色/删除(软删)
 */
function CategoriesSection() {
  const { t } = useLanguage()
  const toast = useToast()
  const { data: expenseCats, reload: reloadExpense } = useCategories('expense')
  const { data: incomeCats, reload: reloadIncome } = useCategories('income')
  const [tab, setTab] = useState<CategoryType>('expense')
  const [showNew, setShowNew] = useState(false)
  const [newName, setNewName] = useState('')
  // 与 uniapp settings/index.vue 同款规则:不选图标 → 纯色填充。
  // 所以默认空串,而不是 '🏷️' 之类的兜底 emoji。
  const [newIcon, setNewIcon] = useState('')
  // 默认灰色背景(对齐 uniapp settings/index.vue 的 #A0AEC0):
  // 之前默认白色时,选中图标底色白底+白卡=反馈色看不出来;
  // 用灰色作为默认值,选图标就能立刻看到颜色预览;白色仍在 COLOR_CHOICES 第一个可选。
  const [newColor, setNewColor] = useState('#A0AEC0')
  const [busy, setBusy] = useState(false)

  // 与 uniapp settings/index.vue 同款候选集基础上扩展:40 个 emoji(系统字体自带,跨平台一致),
  // 21 个品牌色 swatch(含 #FFFFFF)。emoji 候选集也用作"自定义分类 icon 是否合法"的校验白名单。
  const ICON_CHOICES = [
    // uniapp 原有 24
    '🍔', '☕', '🛍️', '🚗', '✈️', '🏠',
    '🎮', '🎵', '💰', '❤️', '🎁', '🐱',
    '🍕', '🍷', '🎬', '📚', '💊', '🎨',
    '⚽', '🚲', '🚌', '✏️', '🎂', '🌹',
    // 新增 16:覆盖更多生活场景(与现有不重复)
    '🍎', '🍞', '🍜', '🍰',        // 食物
    '🍵', '🍺',                   // 饮品
    '🛒', '💳',                   // 购物
    '📱', '💻',                   // 数码
    '🏥', '🏋️',                   // 医疗/健身
    '🎓', '💼',                   // 教育/工作
    '🐶', '🌷',                   // 宠物/植物
    '🗂️',                          // 分类/归档(preset 其他 用)
  ] as const

  const COLOR_CHOICES = [
    // 用户要求:白色作为默认色,放在最前面
    '#FFFFFF',
    // uniapp 原有 12
    '#ED8936', '#4299E1', '#ED64A6', '#805AD5',
    '#8B6E4E', '#E53E3E', '#319795', '#718096',
    '#A0AEC0', '#38B2AC', '#DD6B20', '#D69E2E',
    // 新增 8:Tailwind 500 色阶补 emerald / indigo / violet / yellow / lime 等(与现有不重复)
    '#10b981', '#3b82f6', '#6366f1', '#ec4899',
    '#f43f5e', '#84cc16', '#facc15', '#a855f7',
  ] as const

  const [editing, setEditing] = useState<Category | null>(null)
  const [editName, setEditName] = useState('')
  const [editColor, setEditColor] = useState('')

  const items = tab === 'expense' ? expenseCats : incomeCats

  async function reload(): Promise<void> {
    if (tab === 'expense') await reloadExpense()
    else await reloadIncome()
  }

  async function handleCreate(): Promise<void> {
    if (!newName.trim()) return
    setBusy(true)
    try {
      // 没选图标 → 后端存空串 → 列表渲染纯色圆(uniapp 同款规则)
      await categoriesApi.createCategory({
        type: tab,
        name: newName.trim(),
        icon: newIcon,
        color: newColor,
      })
      setShowNew(false)
      setNewName('')
      setNewIcon('')
      setNewColor('#A0AEC0')
      toast.show(t('settings.categories.create.success'))
      await reload()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('settings.categories.create.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  function openEdit(c: Category): void {
    setEditing(c)
    setEditName(c.name)
    setEditColor(c.color)
  }

  async function handleSaveEdit(): Promise<void> {
    if (!editing) return
    setBusy(true)
    try {
      await categoriesApi.updateCategory(editing.id, {
        name: editName.trim() || undefined,
        color: editColor || undefined,
      })
      setEditing(null)
      toast.show(t('settings.categories.edit.success'))
      await reload()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('settings.categories.edit.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  async function handleDelete(c: Category): Promise<void> {
    if (!window.confirm(t('settings.categories.delete.confirm', { name: c.name }))) return
    setBusy(true)
    try {
      await categoriesApi.deleteCategory(c.id)
      toast.show(t('settings.categories.delete.success'))
      await reload()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('settings.categories.delete.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="bento-item bg-bg-card p-8">
      <div className="flex items-center justify-between mb-6">
        <div className="flex items-center gap-3">
          <span
            className="w-9 h-9 rounded-full flex items-center justify-center bg-primary-light text-primary"
          >
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
            >
              category
            </span>
          </span>
          <h3 className="font-headline-md text-headline-md text-text-primary">
            {t('settings.categories.title')}
          </h3>
        </div>
        <button
          type="button"
          onClick={() => setShowNew((v) => !v)}
          className="inline-flex items-center gap-2 px-3 py-1.5 text-sm bg-primary text-on-primary rounded-lg hover:bg-primary-container transition-colors"
        >
          <span className="material-symbols-outlined" style={{ fontSize: '18px' }}>add</span>
          {t('settings.categories.create.toggle')}
        </button>
      </div>

      <div className="flex gap-2 mb-4">
        {(['expense', 'income'] as CategoryType[]).map((k) => (
          <button
            key={k}
            type="button"
            onClick={() => setTab(k)}
            className={`px-3 py-1.5 text-sm rounded-md transition-colors ${
              tab === k
                ? 'bg-primary-light text-primary font-semibold'
                : 'text-on-surface-variant hover:text-text-primary'
            }`}
          >
            {t(`settings.categories.tab.${k}`)}
          </button>
        ))}
      </div>

      {showNew && (
        <div className="border border-divider rounded-lg p-5 mb-5 space-y-4">
          {/* 名称 */}
          <div className="flex flex-col gap-2">
            <span className="text-xs text-on-surface-variant">{t('settings.categories.field.name')}</span>
            <input
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              maxLength={20}
              className="border border-outline rounded-lg px-3 py-2 text-sm bg-surface-container-lowest focus:border-primary"
              autoFocus
            />
          </div>

          {/* 图标选择:与 uniapp 同款 24 emoji picker grid,点击再点取消选中 */}
          <div className="flex flex-col gap-2">
            <span className="text-xs text-on-surface-variant">{t('settings.categories.field.icon')}</span>
            <div className="grid grid-cols-10 sm:grid-cols-12 md:grid-cols-16 gap-1.5">
              {ICON_CHOICES.map((icon) => {
                const active = newIcon === icon
                // 选中态:背景 = newColor(实时预览「图标 + 颜色」的最终效果),
                // 边框永远 = primary(反馈色,与 newColor 解耦 → 即使选白色也能看出已选);
                // 白色背景时 emoji 切深字。无 ✓ 徽章。
                const isWhiteBg = active && newColor.toUpperCase() === '#FFFFFF'
                return (
                  <button
                    key={icon}
                    type="button"
                    onClick={() => setNewIcon(active ? '' : icon)}
                    aria-pressed={active}
                    title={icon}
                    className={
                      'w-10 h-10 rounded-lg border-2 flex items-center justify-center text-xl transition-all ' +
                      (active
                        ? 'border-primary ' + (isWhiteBg ? 'text-text-primary' : 'text-white')
                        : 'border-outline bg-surface-container-lowest hover:border-primary')
                    }
                    style={active ? { backgroundColor: newColor } : undefined}
                  >
                    {icon}
                  </button>
                )
              })}
            </div>
            <span className="text-xs text-on-surface-variant">不选图标 = 纯色填充</span>
          </div>

          {/* 颜色选择:与 uniapp 同款 12 swatch grid */}
          <div className="flex flex-col gap-2">
            <span className="text-xs text-on-surface-variant">{t('settings.categories.field.color')}</span>
            <div className="flex flex-wrap gap-2">
              {COLOR_CHOICES.map((color) => {
                const active = newColor === color
                // 白色 swatch:勾选用深色,且始终保留 outline 边框,
                // 否则白底白卡 + 透明边框 → 完全看不见。
                const isWhite = color.toUpperCase() === '#FFFFFF'
                return (
                  <button
                    key={color}
                    type="button"
                    onClick={() => setNewColor(color)}
                    aria-pressed={active}
                    aria-label={color}
                    className={
                      'w-9 h-9 rounded-full flex items-center justify-center transition-all border-2 ' +
                      (active
                        ? 'border-text-primary'
                        : (isWhite ? 'border-outline' : 'border-transparent'))
                    }
                    style={{ backgroundColor: color }}
                  >
                    {active && (
                      <span className={(isWhite ? 'text-text-primary' : 'text-white') + ' text-base leading-none'}>
                        ✓
                      </span>
                    )}
                  </button>
                )
              })}
            </div>
          </div>

          {/* 取消 / 保存 */}
          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={() => setShowNew(false)}
              className="px-3 py-1.5 text-sm border border-outline rounded-lg hover:bg-surface-container-low"
            >
              {t('common.cancel')}
            </button>
            <button
              type="button"
              onClick={handleCreate}
              disabled={busy || !newName.trim()}
              className="px-3 py-1.5 text-sm bg-primary text-on-primary rounded-lg disabled:opacity-50"
            >
              {t('common.save')}
            </button>
          </div>
        </div>
      )}

      <div className="divide-y divide-divider">
        {items?.map((c) => {
          // 自定义分类:校验 icon 是否在 emoji 白名单里。后端可能存了旧的 Material Symbols
          // ligature 名字(如 "restaurant"),直接渲染会显示成英文乱码。
          // 没选 / 非白名单 → 走「纯色填充」规则(对齐 uniapp settings/index.vue disp.solid)。
          const rawIcon = c.icon ?? ''
          const validIcon = (rawIcon && (ICON_CHOICES as readonly string[]).includes(rawIcon)) ? rawIcon : ''
          const solid = !validIcon
          // 白色背景 + 实色填充 → 白卡白点看不见,加一圈 outline 描边保可见性。
          const isWhiteBg = solid && c.color.toUpperCase() === '#FFFFFF'
          return (
          <div key={c.id} className="flex items-center gap-3 py-3">
            <span
              className={
                'w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ' +
                (isWhiteBg ? 'border border-outline' : '')
              }
              // 没图标 → 实色圆;有图标 → 半透明背景 + 彩色 emoji
              style={{ backgroundColor: solid ? c.color : c.color + '33' }}
            >
              {validIcon && (
                <span style={{ fontSize: '18px', color: solid ? '#fff' : c.color }}>
                  {validIcon}
                </span>
              )}
            </span>
            <div className="flex-1 min-w-0">
              <p className="text-sm text-text-primary truncate">{c.name}</p>
              <p className="text-xs text-on-surface-variant truncate">{c.color}</p>
            </div>
            <div className="flex items-center gap-2 flex-shrink-0">
              {c.isPreset ? (
                <span className="px-2 py-0.5 rounded-full text-xs bg-surface-container-low text-on-surface-variant">
                  {t('settings.categories.presetBadge')}
                </span>
              ) : (
                <>
                  <button
                    type="button"
                    onClick={() => openEdit(c)}
                    className="px-3 py-1.5 text-sm border border-outline rounded-lg hover:bg-surface-container-low"
                  >
                    {t('common.edit')}
                  </button>
                  <button
                    type="button"
                    onClick={() => handleDelete(c)}
                    disabled={busy}
                    className="px-3 py-1.5 text-sm border border-error text-error rounded-lg hover:bg-error hover:text-white disabled:opacity-50"
                  >
                    {t('common.delete')}
                  </button>
                </>
              )}
            </div>
          </div>
          )
        })}
        {items && items.length === 0 && (
          <p className="text-sm text-on-surface-variant py-6 text-center">{t('common.empty')}</p>
        )}
      </div>

      {editing && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
          <div className="bg-bg-card rounded-xl p-6 w-full max-w-md">
            <h3 className="font-headline-md text-headline-md text-text-primary mb-4">
              {t('settings.categories.edit.title')}
            </h3>
            <label className="flex flex-col gap-1 mb-3">
              <span className="text-xs text-on-surface-variant">{t('settings.categories.field.name')}</span>
              <input
                value={editName}
                onChange={(e) => setEditName(e.target.value)}
                maxLength={20}
                className="border border-outline rounded-lg px-3 py-2 text-sm bg-surface-container-lowest focus:border-primary"
              />
            </label>
            <label className="flex flex-col gap-1 mb-4">
              <span className="text-xs text-on-surface-variant">{t('settings.categories.field.color')}</span>
              <input
                type="color"
                value={editColor}
                onChange={(e) => setEditColor(e.target.value)}
                className="border border-outline rounded-lg h-10 w-full bg-surface-container-lowest"
              />
            </label>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setEditing(null)}
                className="px-4 py-2 text-sm border border-outline rounded-lg"
              >
                {t('common.cancel')}
              </button>
              <button
                type="button"
                onClick={handleSaveEdit}
                disabled={busy}
                className="px-4 py-2 text-sm bg-primary text-on-primary rounded-lg disabled:opacity-50"
              >
                {t('common.save')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}