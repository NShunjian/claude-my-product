import { useMemo } from 'react'
import { Link } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { ACCOUNTS } from '../data/accounts'
import { TRANSACTIONS } from '../data/transactions'
import { EXPENSE_CATEGORIES, INCOME_CATEGORIES } from '../data/categories'
import { TransactionRow } from '../components/TransactionRow'
import { CategoryBreakdown } from '../components/CategoryBreakdown'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

function findAccount(id: string) {
  return ACCOUNTS.find((a) => a.id === id)
}

/**
  Format a date label like "今天，8月24日" / "昨天，8月23日" / "8月22日"
  relative to a fixed "today" (2026-08-26) so seed data renders consistently.
*/
function dateLabel(iso: string, today: Date): string {
  const d = new Date(iso)
  const sameDay = (a: Date, b: Date): boolean =>
    a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
  const monthDay = `${d.getMonth() + 1}月${d.getDate()}日`
  if (sameDay(d, today)) return `今天，${monthDay}`
  const yesterday = new Date(today)
  yesterday.setDate(today.getDate() - 1)
  if (sameDay(d, yesterday)) return `昨天，${monthDay}`
  return monthDay
}

export function Home() {
  usePageTitle('首页')
  usePageBack(null)

  const thisMonthTxns = useMemo(() => {
    const now = new Date(2026, 7, 26) // 2026-08-26
    return TRANSACTIONS.filter((t) => {
      const d = new Date(t.date)
      return d.getFullYear() === now.getFullYear() && d.getMonth() === now.getMonth()
    })
  }, [])

  const thisMonthIncome = useMemo(
    () => thisMonthTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0),
    [thisMonthTxns],
  )

  const thisMonthExpense = useMemo(
    () => thisMonthTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [thisMonthTxns],
  )

  const totalAssets = useMemo(
    () => ACCOUNTS.reduce((s, a) => s + a.balance, 0),
    [],
  )

  const monthlyBalance = thisMonthIncome - thisMonthExpense

  const recentTxns = thisMonthTxns.slice(0, 8)

  // Group recent transactions by date for prototype-style rendering
  const groupedTxns = useMemo(() => {
    const today = new Date(2026, 7, 26)
    const groups = new Map<string, typeof recentTxns>()
    for (const t of recentTxns) {
      const key = t.date
      const arr = groups.get(key) ?? []
      arr.push(t)
      groups.set(key, arr)
    }
    return Array.from(groups.entries()).map(([date, txns]) => {
      const net = txns.reduce(
        (s, t) => s + (t.type === 'income' ? t.amount : -t.amount),
        0,
      )
      return { date, txns, net, label: dateLabel(date, today) }
    })
  }, [recentTxns])

  return (
    <div className="space-y-6">
      {/* Month selector */}
      <div className="flex justify-between items-end">
        <div>
          <h2 className="font-display-lg text-display-lg text-text-primary mb-1">总览</h2>
          <div className="flex items-center gap-2 text-on-surface-variant font-headline-md text-headline-md cursor-pointer hover:text-primary transition-colors">
            <span>8月 2023</span>
            <span className="material-symbols-outlined text-sm">expand_more</span>
          </div>
        </div>
      </div>

      {/* Overview cards */}
      {/* Row 1: 总资产 (prominent, full width) */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm relative overflow-hidden">
        <div className="absolute top-0 right-0 p-4 opacity-10 pointer-events-none">
          <span
            className="material-symbols-outlined text-primary"
            style={{ fontSize: '80px', lineHeight: 1, display: 'block' }}
          >
            account_balance_wallet
          </span>
        </div>
        <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">总资产</p>
        <div className="flex items-baseline gap-1">
          <span className="font-label-mono text-label-mono text-primary">¥</span>
          <span className="font-label-mono text-[40px] leading-tight text-primary font-bold">
            {formatMoney(totalAssets)}
          </span>
        </div>
        <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-2">
          共 {ACCOUNTS.length} 个账户
        </p>
      </div>

      {/* Row 2: 本月支出 + 本月收入 + 当月结余 */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {/* 本月支出 */}
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity pointer-events-none">
            <span
              className="material-symbols-outlined text-error"
              style={{ fontSize: '60px', lineHeight: 1, display: 'block' }}
            >
              trending_down
            </span>
          </div>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">本月支出</p>
          <div className="flex items-baseline gap-1">
            <span className="font-label-mono text-label-mono text-error">¥</span>
            <span className="font-label-mono text-[32px] leading-tight text-error font-bold">
              {formatMoney(thisMonthExpense)}
            </span>
          </div>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-2">较上月: +12%</p>
        </div>
        {/* 本月收入 */}
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity pointer-events-none">
            <span
              className="material-symbols-outlined text-secondary"
              style={{ fontSize: '60px', lineHeight: 1, display: 'block' }}
            >
              trending_up
            </span>
          </div>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">本月收入</p>
          <div className="flex items-baseline gap-1">
            <span className="font-label-mono text-label-mono text-secondary">¥</span>
            <span className="font-label-mono text-[32px] leading-tight text-secondary font-bold">
              {formatMoney(thisMonthIncome)}
            </span>
          </div>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-2">较上月: +5%</p>
        </div>
        {/* 当月结余 */}
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-4 opacity-10 group-hover:opacity-20 transition-opacity pointer-events-none">
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '60px', lineHeight: 1, display: 'block', color: monthlyBalance >= 0 ? '#006d40' : '#ba1a1a' }}
            >
              {monthlyBalance >= 0 ? 'trending_up' : 'trending_down'}
            </span>
          </div>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">当月结余</p>
          <div className="flex items-baseline gap-1">
            <span
              className="font-label-mono text-label-mono"
              style={{ color: monthlyBalance >= 0 ? '#006d40' : '#ba1a1a' }}
            >
              {monthlyBalance >= 0 ? '¥' : '-¥'}
            </span>
            <span
              className="font-label-mono text-[32px] leading-tight font-bold"
              style={{ color: monthlyBalance >= 0 ? '#006d40' : '#ba1a1a' }}
            >
              {formatMoney(Math.abs(monthlyBalance))}
            </span>
          </div>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-2">
            {monthlyBalance >= 0 ? '盈余' : '超支'}
          </p>
        </div>
      </div>

      {/* Recent transactions (date-grouped) */}
      <div className="bg-bg-card rounded-xl border border-divider shadow-sm overflow-hidden">
        <div className="p-4 border-b border-divider bg-surface-bright flex justify-between items-center">
          <h3 className="font-headline-md text-headline-md text-text-primary">最近交易</h3>
          <Link to="/transactions" className="text-primary hover:text-primary-container font-caption-sm text-caption-sm flex items-center gap-1">
            查看全部 <span className="material-symbols-outlined" style={{ fontSize: '16px' }}>arrow_forward</span>
          </Link>
        </div>

        <div className="p-4">
          {recentTxns.length === 0 ? (
            <p className="text-on-surface-variant font-body-md text-body-md text-center py-8">暂无交易记录</p>
          ) : (
            groupedTxns.map((group, idx) => (
              <div key={group.date} className={idx === groupedTxns.length - 1 ? '' : 'mb-6'}>
                <div className="flex justify-between items-center mb-2">
                  <span className="font-caption-sm text-caption-sm text-on-surface-variant font-semibold">
                    {group.label}
                  </span>
                  <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                    {group.net >= 0 ? '¥' : '¥ -'}{Math.abs(group.net).toFixed(2)}
                  </span>
                </div>
                <div className="flex flex-col gap-1">
                  {group.txns.map((txn) => (
                    <TransactionRow
                      key={txn.id}
                      transaction={txn}
                      account={findAccount(txn.accountId)}
                    />
                  ))}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Category breakdown: 支出分类 (left) + 收入分类 (right) */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <CategoryBreakdown
          title="支出分类"
          categories={EXPENSE_CATEGORIES}
          transactions={thisMonthTxns}
          type="expense"
          totalAmount={thisMonthExpense}
        />
        <CategoryBreakdown
          title="收入分类"
          categories={INCOME_CATEGORIES}
          transactions={thisMonthTxns}
          type="income"
          totalAmount={thisMonthIncome}
        />
      </div>
    </div>
  )
}
