import { useMemo } from 'react'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { useAccounts } from '../lib/hooks'
import { toAccounts } from '../lib/finance-mappers'
import { Link } from 'react-router-dom'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

const ACCOUNT_THEME: Record<
  string,
  { iconBg: string; iconColor: string; iconName: string }
> = {
  wechat: { iconBg: '#E5F5E9', iconColor: '#09B83E', iconName: 'chat_bubble' },
  alipay: { iconBg: '#E3F2FD', iconColor: '#1677FF', iconName: 'payments' },
  bank: { iconBg: '#e5eeff', iconColor: '#005394', iconName: 'account_balance' },
  credit: { iconBg: 'rgb(167 8 25 / 0.12)', iconColor: '#ba1a1a', iconName: 'credit_card' },
  cash: { iconBg: '#dce9ff', iconColor: '#8B6E4E', iconName: 'local_atm' },
}

export function Accounts() {
  usePageTitle('账户管理')
  usePageBack(null)

  const accountsQ = useAccounts()
  const accounts = useMemo(() => (accountsQ.data ? toAccounts(accountsQ.data) : []), [accountsQ.data])

  const totalBalance = accounts.reduce((s, a) => s + a.balance, 0)
  const isLoading = accountsQ.loading
  const isError = !isLoading && !!accountsQ.error
  const errMsg = accountsQ.error?.message ?? null

  return (
    <div className="space-y-6">
      {/* 资产净值 + 添加账户 */}
      <section className="bg-bg-card rounded-xl p-6 border border-divider shadow-sm relative overflow-hidden">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div>
            <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1 uppercase tracking-wider">
              资产净值
            </p>
            <div className="flex items-baseline gap-2">
              <span className="font-display-lg text-display-lg font-bold text-text-primary">
                ¥{formatMoney(totalBalance)}
              </span>
              <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full font-caption-sm text-caption-sm text-secondary bg-secondary-container/40">
                <span
                  className="material-symbols-outlined"
                  style={{ fontSize: '14px', fontVariationSettings: "'FILL' 1" }}
                >
                  trending_up
                </span>
                +2.4%
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
            添加账户
          </Link>
        </div>
      </section>

      {isError && (
        <div className="bg-error-container text-on-error-container rounded-xl p-4 font-body-md text-body-md">
          加载失败：{errMsg}
        </div>
      )}

      {/* 账户卡片网格 */}
      <section className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 md:gap-6">
        {isLoading ? (
          <p className="col-span-full text-on-surface-variant font-body-md text-body-md text-center py-12">
            加载中…
          </p>
        ) : accounts.length === 0 ? (
          <p className="col-span-full text-on-surface-variant font-body-md text-body-md text-center py-12">
            暂无账户
          </p>
        ) : (
          accounts.map((acc) => {
            const theme = ACCOUNT_THEME[acc.themeKey] ?? ACCOUNT_THEME.bank
            const isCredit = acc.themeKey === 'credit'
            return (
              <article
                key={acc.id}
                className="bg-bg-card rounded-xl p-5 border border-divider shadow-sm hover:shadow-[0_4px_12px_rgba(0,0,0,0.04)] transition-shadow group relative cursor-pointer"
              >
                <div className="flex justify-between items-start mb-6">
                  <div
                    className="w-12 h-12 rounded-full flex items-center justify-center"
                    style={{ backgroundColor: theme.iconBg }}
                  >
                    <span
                      className="material-symbols-outlined text-2xl"
                      style={{ color: theme.iconColor, fontVariationSettings: "'FILL' 1" }}
                    >
                      {theme.iconName}
                    </span>
                  </div>
                  <button
                    type="button"
                    className="text-outline hover:text-on-surface-variant transition-colors opacity-0 group-hover:opacity-100 focus:opacity-100"
                    aria-label="更多操作"
                  >
                    <span className="material-symbols-outlined">more_horiz</span>
                  </button>
                </div>

                <div>
                  <h3 className="font-headline-md text-headline-md text-on-surface mb-1">
                    {acc.name}
                  </h3>
                  <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-4">
                    {acc.subtitle}
                  </p>

                  {isCredit ? (
                    <div className="flex justify-between items-end">
                      <p className="font-label-mono text-label-mono text-error">
                        -¥{formatMoney(Math.abs(acc.balance))}
                      </p>
                      {acc.creditLimit && (
                        <span className="font-caption-sm text-caption-sm text-outline">
                          Limit: ¥{acc.creditLimit}
                        </span>
                      )}
                    </div>
                  ) : (
                    <p className="font-label-mono text-label-mono text-on-surface">
                      ¥{formatMoney(acc.balance)}
                    </p>
                  )}
                </div>
              </article>
            )
          })
        )}
      </section>
    </div>
  )
}