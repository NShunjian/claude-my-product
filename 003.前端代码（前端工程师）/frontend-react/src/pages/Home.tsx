import { useMemo } from 'react'
import { Link } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { TransactionRow } from '../components/TransactionRow'
import { CategoryBreakdown } from '../components/CategoryBreakdown'
import { useAccounts, useCategories, useRecords } from '../lib/hooks'
import { toAccounts, toCategories, toTransactions } from '../lib/finance-mappers'
import type { Account, Category, Transaction } from '../lib/finance-types'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

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

function currentMonthYYYYMM(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

function currentMonthLabel(): string {
  const d = new Date()
  return `${d.getMonth() + 1}月 ${d.getFullYear()}`
}

export function Home() {
  usePageTitle('首页')
  usePageBack(null)

  const month = useMemo(currentMonthYYYYMM, [])
  const today = useMemo(() => new Date(), [])

  const accountsQ = useAccounts()
  const expenseCatsQ = useCategories('expense')
  const incomeCatsQ = useCategories('income')
  const recordsQ = useRecords({ month })

  const accounts = useMemo<Account[]>(
    () => (accountsQ.data ? toAccounts(accountsQ.data) : []),
    [accountsQ.data],
  )
  const expenseCats = useMemo<Category[]>(
    () => (expenseCatsQ.data ? toCategories(expenseCatsQ.data) : []),
    [expenseCatsQ.data],
  )
  const incomeCats = useMemo<Category[]>(
    () => (incomeCatsQ.data ? toCategories(incomeCatsQ.data) : []),
    [incomeCatsQ.data],
  )
  const allTxns = useMemo<Transaction[]>(
    () => (recordsQ.data ? toTransactions(recordsQ.data) : []),
    [recordsQ.data],
  )

  const thisMonthTxns = allTxns

  const thisMonthIncome = useMemo(
    () => thisMonthTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0),
    [thisMonthTxns],
  )

  const thisMonthExpense = useMemo(
    () => thisMonthTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [thisMonthTxns],
  )

  const totalAssets = useMemo(
    () => accounts.reduce((s, a) => s + a.balance, 0),
    [accounts],
  )

  const monthlyBalance = thisMonthIncome - thisMonthExpense

  const recentTxns = thisMonthTxns.slice(0, 8)

  const groupedTxns = useMemo(() => {
    const groups = new Map<string, Transaction[]>()
    for (const t of recentTxns) {
      const arr = groups.get(t.date) ?? []
      arr.push(t)
      groups.set(t.date, arr)
    }
    return Array.from(groups.entries()).map(([date, txns]) => {
      const net = txns.reduce(
        (s, t) => s + (t.type === 'income' ? t.amount : -t.amount),
        0,
      )
      return { date, txns, net, label: dateLabel(date, today) }
    })
  }, [recentTxns, today])

  const findAccount = (id: string): Account | undefined =>
    accounts.find((a) => a.id === id)

  const isLoading = accountsQ.loading || recordsQ.loading
  const isError = !isLoading && (!!accountsQ.error || !!recordsQ.error)
  const errMsg = accountsQ.error?.message ?? recordsQ.error?.message ?? null

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="font-display-lg text-display-lg text-text-primary mb-1">总览</h2>
          <div className="flex items-center gap-2 text-on-surface-variant font-headline-md text-headline-md">
            <span>{currentMonthLabel()}</span>
          </div>
        </div>
      </div>

      {isError && (
        <div className="bg-error-container text-on-error-container rounded-xl p-4 font-body-md text-body-md">
          加载失败：{errMsg}
        </div>
      )}

      {/* Row 1: 总资产 */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm relative overflow-hidden">
        <div className="absolute top-0 right-0 p-4 opacity-10 pointer-events-none">
          <span className="material-symbols-outlined text-primary" style={{ fontSize: '80px', lineHeight: 1, display: 'block' }}>
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
          共 {accounts.length} 个账户
        </p>
      </div>

      {/* Row 2: 三张 KPI 卡 */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">本月支出</p>
          <div className="flex items-baseline gap-1">
            <span className="font-label-mono text-label-mono text-error">¥</span>
            <span className="font-label-mono text-[32px] leading-tight text-error font-bold">
              {formatMoney(thisMonthExpense)}
            </span>
          </div>
        </div>
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">本月收入</p>
          <div className="flex items-baseline gap-1">
            <span className="font-label-mono text-label-mono text-secondary">¥</span>
            <span className="font-label-mono text-[32px] leading-tight text-secondary font-bold">
              {formatMoney(thisMonthIncome)}
            </span>
          </div>
        </div>
        <div className="bg-bg-card rounded-xl border border-divider p-4 shadow-sm relative overflow-hidden">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-2">当月结余</p>
          <div className="flex items-baseline gap-1">
            <span className="font-label-mono text-label-mono" style={{ color: monthlyBalance >= 0 ? '#006d40' : '#ba1a1a' }}>
              {monthlyBalance >= 0 ? '¥' : '-¥'}
            </span>
            <span className="font-label-mono text-[32px] leading-tight font-bold" style={{ color: monthlyBalance >= 0 ? '#006d40' : '#ba1a1a' }}>
              {formatMoney(Math.abs(monthlyBalance))}
            </span>
          </div>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-2">
            {monthlyBalance >= 0 ? '盈余' : '超支'}
          </p>
        </div>
      </div>

      {/* 最近交易 */}
      <div className="bg-bg-card rounded-xl border border-divider shadow-sm overflow-hidden">
        <div className="p-4 border-b border-divider bg-surface-bright flex justify-between items-center">
          <h3 className="font-headline-md text-headline-md text-text-primary">最近交易</h3>
          <Link to="/transactions" className="text-primary hover:text-primary-container font-caption-sm text-caption-sm flex items-center gap-1">
            查看全部 <span className="material-symbols-outlined" style={{ fontSize: '16px' }}>arrow_forward</span>
          </Link>
        </div>
        <div className="p-4">
          {isLoading ? (
            <p className="text-on-surface-variant font-body-md text-body-md text-center py-8">加载中…</p>
          ) : recentTxns.length === 0 ? (
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
                      categories={[...expenseCats, ...incomeCats]}
                    />
                  ))}
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Category breakdown */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <CategoryBreakdown
          title="支出分类"
          categories={expenseCats}
          transactions={thisMonthTxns}
          type="expense"
          totalAmount={thisMonthExpense}
        />
        <CategoryBreakdown
          title="收入分类"
          categories={incomeCats}
          transactions={thisMonthTxns}
          type="income"
          totalAmount={thisMonthIncome}
        />
      </div>
    </div>
  )
}
