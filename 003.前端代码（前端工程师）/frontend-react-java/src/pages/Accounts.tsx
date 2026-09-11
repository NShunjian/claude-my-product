import { useMemo, useState } from 'react'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { useAccounts } from '../lib/hooks'
import { toAccounts } from '../lib/finance-mappers'
import { Link } from 'react-router-dom'
import { useLanguage } from '../i18n/LanguageContext'
import * as accountsApi from '../api/accounts'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

const ACCOUNT_THEME: Record<
  string,
  { iconBg: string; iconColor: string }
> = {
  // 对齐 007 uniapp themeMap + Flutter _icons:iconName 现在是 emoji 字符
  // (后端 acc.icon 优先),这里只保留 iconBg / iconColor 给底圈染色。
  wechat: { iconBg: '#E5F5E9', iconColor: '#09B83E' },
  alipay: { iconBg: '#E3F2FD', iconColor: '#1677FF' },
  bank:   { iconBg: '#e5eeff', iconColor: '#005394' },
  credit: { iconBg: 'rgb(167 8 25 / 0.12)', iconColor: '#ba1a1a' },
  cash:   { iconBg: '#dce9ff', iconColor: '#8B6E4E' },
}

/** 0=active only, 1=all(活跃+归档), 2=archived only。默认 active。 */
type FilterMode = 'active' | 'all' | 'archived'

export function Accounts() {
  const { t } = useLanguage()
  usePageTitle(t('accounts.titleManage'))
  usePageBack(null)

  // ponytail: 一次拉全量(active + archived),前端按 filterMode 切片。
  //          默认 useAccounts() 不传 includeArchived,跟其它页面(只显示活跃账户)
  //          行为一致。
  const accountsQ = useAccounts({ includeArchived: true })
  const accounts = useMemo(() => (accountsQ.data ? toAccounts(accountsQ.data) : []), [accountsQ.data])

  const [filter, setFilter] = useState<FilterMode>('active')
  const visible = useMemo(() => {
    if (filter === 'all') return accounts
    if (filter === 'archived') return accounts.filter((a) => a.isArchived)
    return accounts.filter((a) => !a.isArchived)
  }, [accounts, filter])

  const totalBalance = visible.reduce((s, a) => s + a.balance, 0)
  const isLoading = accountsQ.loading
  const isError = !isLoading && !!accountsQ.error
  const errMsg = accountsQ.error?.message ?? null

  async function handleArchive(id: string, name: string, currentArchived: boolean) {
    const ok = window.confirm(
      currentArchived
        ? t('accounts.unarchiveConfirm', { name })
        : t('accounts.archiveConfirm', { name })
    )
    if (!ok) return
    try {
      if (currentArchived) {
        await accountsApi.unarchiveAccount(id)
      } else {
        await accountsApi.archiveAccount(id)
      }
      accountsQ.reload()
    } catch (err) {
      alert((err as Error)?.message ?? String(err))
    }
  }

  async function handleDelete(id: string) {
    if (!window.confirm(t('accounts.deleteConfirm'))) return
    try {
      await accountsApi.deleteAccount(id)
      accountsQ.reload()
    } catch (err) {
      alert((err as Error)?.message ?? String(err))
    }
  }

  return (
    <div className="space-y-6">
      {/* 资产净值 + 添加账户 */}
      <section className="bg-bg-card rounded-xl p-6 border border-divider shadow-sm relative overflow-hidden">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div>
            <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1 uppercase tracking-wider">
              {t('accounts.netAssets')}
            </p>
            <div className="flex items-baseline gap-2">
              <span
                className={`font-display-lg text-display-lg font-bold ${
                  totalBalance < 0 ? 'text-error' : 'text-text-primary'
                }`}
              >
                ¥{formatMoney(totalBalance)}
              </span>
            </div>
          </div>
          <Link
            to="/accounts/new"
            className="flex items-center justify-center gap-2 bg-primary text-on-primary font-headline-md text-headline-md py-2.5 px-6 rounded-lg shadow-[0_2px_8px_rgba(0,83,148,0.2)] hover:bg-primary-container transition-all active:scale-95 w-full md:w-auto"
          >
            <span
              className="material-symbols-outlined"
              style={{ fontVariationSettings: "'FILL' 1" }}
            >
              add_circle
            </span>
            {t('accounts.addCta')}
          </Link>
        </div>
      </section>

      {/* Filter chips — 三档:活跃 / 全部 / 已归档 */}
      <section className="flex gap-2">
        {(['active', 'all', 'archived'] as FilterMode[]).map((mode) => {
          const selected = filter === mode
          const label =
            mode === 'active'
              ? t('accounts.filter.active')
              : mode === 'all'
              ? t('accounts.filter.all')
              : t('accounts.filter.archivedOnly')
          return (
            <button
              key={mode}
              type="button"
              onClick={() => setFilter(mode)}
              className={`px-4 py-1.5 rounded-full font-caption-md text-caption-md border transition-colors ${
                selected
                  ? 'bg-primary text-on-primary border-primary'
                  : 'bg-bg-card text-on-surface-variant border-divider hover:border-primary'
              }`}
            >
              {label}
            </button>
          )
        })}
      </section>

      {isError && (
        <div className="bg-error-container text-on-error-container rounded-xl p-4 font-body-md text-body-md">
          {t('accounts.loadErrorPrefix')}{errMsg}
        </div>
      )}

      {/* 账户卡片网格 */}
      <section className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
        {isLoading ? (
          <p className="col-span-full text-on-surface-variant font-body-md text-body-md text-center py-12">
            {t('accounts.loading')}
          </p>
        ) : visible.length === 0 ? (
          <p className="col-span-full text-on-surface-variant font-body-md text-body-md text-center py-12">
            {t('accounts.empty')}
          </p>
        ) : (
          visible.map((acc) => {
            const theme = ACCOUNT_THEME[acc.themeKey] ?? ACCOUNT_THEME.bank
            return (
              <article
                key={acc.id}
                // ponytail: 归档卡片整体透明度 0.5,跟 uniapp / Flutter 三端一致。
                className={`bg-bg-card rounded-xl p-5 border border-divider shadow-sm hover:shadow-[0_4px_12px_rgba(0,0,0,0.04)] transition-shadow group relative ${
                  acc.isArchived ? 'opacity-50' : ''
                }`}
              >
                <div className="flex justify-between items-start mb-6">
                  <div
                    className="w-12 h-12 rounded-full flex items-center justify-center text-2xl"
                    style={{ backgroundColor: theme.iconBg, color: theme.iconColor }}
                  >
                    {/* emoji 字(来自后端 acc.icon 或 themeKey 兜底),对齐 uniapp/Flutter */}
                    <span aria-hidden="true">{acc.icon}</span>
                  </div>
                  {/* ponytail: 卡片右上角更多菜单 — 用原生 <details>/<summary>
                              配合下拉,避免引第三方 popover 库;同 macOS/Windows/移动
                              浏览器一致行为。点击外部收起靠 <details> open 状态切
                              换(<details> 点击外部不会自动关,但可接受,跟对话体验
                              接近)。 */}
                  <details className="relative">
                    <summary
                      className="list-none cursor-pointer text-outline hover:text-on-surface-variant transition-colors"
                      aria-label={t('accounts.moreActions')}
                    >
                      <span className="material-symbols-outlined">more_horiz</span>
                    </summary>
                    <div className="absolute right-0 mt-2 min-w-[160px] bg-bg-card border border-divider rounded-lg shadow-lg z-10 overflow-hidden">
                      <button
                        type="button"
                        onClick={(e) => {
                          e.preventDefault()
                          handleArchive(acc.id, acc.name, !!acc.isArchived)
                        }}
                        className="w-full text-left px-4 py-2 font-body-md text-body-md hover:bg-primary-container transition-colors"
                      >
                        {acc.isArchived ? t('accounts.unarchive') : t('accounts.archive')}
                      </button>
                      <button
                        type="button"
                        onClick={(e) => {
                          e.preventDefault()
                          handleDelete(acc.id)
                        }}
                        className="w-full text-left px-4 py-2 font-body-md text-body-md text-error hover:bg-error-container transition-colors border-t border-divider"
                      >
                        {t('common.delete')}
                      </button>
                    </div>
                  </details>
                </div>

                <div>
                  <div className="flex items-center gap-2 mb-1">
                    <h3 className="font-headline-md text-headline-md text-on-surface">
                      {acc.name}
                    </h3>
                    {acc.isArchived && (
                      <span className="inline-flex items-center px-2 py-0.5 rounded font-caption-sm text-caption-sm bg-divider text-on-surface-variant">
                        {t('accounts.archivedBadge')}
                      </span>
                    )}
                  </div>
                  <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-4">
                    {acc.subtitle}
                  </p>

                  {/* 真实余额:formatMoney(toLocaleString) 自动给负数带 '-'。
                      账户页规则:负数(透支/欠款)=红色,正数/0=默认色 —— 收入不强调绿色。 */}
                  <p
                    className={`font-label-mono text-label-mono ${
                      acc.balance < 0 ? 'text-error' : 'text-on-surface'
                    }`}
                  >
                    ¥{formatMoney(acc.balance)}
                  </p>
                </div>
              </article>
            )
          })
        )}
      </section>
    </div>
  )
}
