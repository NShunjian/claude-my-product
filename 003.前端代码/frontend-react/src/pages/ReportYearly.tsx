import { useMemo } from 'react'
import { usePageTitle } from '../components/PageTitleContext'
import { TRANSACTIONS } from '../data/transactions'
import { ACCOUNTS } from '../data/accounts'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

export function ReportYearly() {
  usePageTitle('报表')

  const yearlyTxns = useMemo(() => {
    return TRANSACTIONS.filter((t) => t.date.startsWith('2026'))
  }, [])

  const totalIncome = useMemo(
    () => yearlyTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0),
    [yearlyTxns],
  )

  const totalExpense = useMemo(
    () => yearlyTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [yearlyTxns],
  )

  const netSavings = totalIncome - totalExpense

  const monthlyData = useMemo(() => {
    const months = ['01', '02', '03', '04', '05', '06', '07', '08']
    return months.map((m) => {
      const monthTxns = yearlyTxns.filter((t) => t.date.slice(5, 7) === m)
      const income = monthTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0)
      const expense = monthTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0)
      return { month: m, income, expense }
    })
  }, [yearlyTxns])

  const maxMonthly = useMemo(
    () => Math.max(...monthlyData.map((d) => Math.max(d.income, d.expense))),
    [monthlyData],
  )

  const monthLabels = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月']

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-end">
        <div>
          <h2 className="font-display-lg text-display-lg text-text-primary mb-1">报表</h2>
          <div className="flex items-center gap-2 text-on-surface-variant font-headline-md text-headline-md cursor-pointer hover:text-primary transition-colors">
            <span>2026 年</span>
            <span className="material-symbols-outlined text-sm">expand_more</span>
          </div>
        </div>
        <div className="flex gap-2">
          <a
            href="/reports/monthly"
            className="px-4 py-2 bg-surface-container text-on-surface-variant font-body-md text-body-md rounded-lg hover:bg-surface-container-high transition-colors"
          >
            月报
          </a>
          <a
            href="/reports/yearly"
            className="px-4 py-2 bg-primary-light text-primary font-body-md text-body-md rounded-lg font-semibold"
          >
            年报
          </a>
        </div>
      </div>

      {/* Summary */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1">年度收入</p>
          <p className="font-label-mono text-label-mono text-secondary">
            +¥{formatMoney(totalIncome)}
          </p>
        </div>
        <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1">年度支出</p>
          <p className="font-label-mono text-label-mono text-error">
            -¥{formatMoney(totalExpense)}
          </p>
        </div>
        <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1">年度结余</p>
          <p className={`font-label-mono text-label-mono ${netSavings >= 0 ? 'text-primary' : 'text-error'}`}>
            {netSavings >= 0 ? '+' : '-'}¥{formatMoney(Math.abs(netSavings))}
          </p>
        </div>
      </div>

      {/* Monthly bar chart (CSS only) */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
        <h3 className="font-headline-md text-headline-md text-text-primary mb-6">月度收支</h3>
        <div className="flex items-end gap-3 h-48">
          {monthlyData.map((d, i) => {
            const incomeH = maxMonthly > 0 ? (d.income / maxMonthly) * 100 : 0
            const expenseH = maxMonthly > 0 ? (d.expense / maxMonthly) * 100 : 0
            return (
              <div key={d.month} className="flex-1 flex flex-col items-center gap-1">
                <div className="w-full flex flex-col-reverse gap-0.5 h-full justify-start">
                  <div
                    className="w-full bg-secondary rounded-t-sm transition-all min-h-[2px]"
                    style={{ height: `${incomeH}%` }}
                    title={`收入 ¥${formatMoney(d.income)}`}
                  />
                  <div
                    className="w-full bg-error rounded-t-sm transition-all min-h-[2px]"
                    style={{ height: `${expenseH}%` }}
                    title={`支出 ¥${formatMoney(d.expense)}`}
                  />
                </div>
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                  {monthLabels[i]}
                </span>
              </div>
            )
          })}
        </div>
        <div className="flex items-center gap-6 mt-4 justify-center">
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-sm bg-secondary" />
            <span className="font-caption-sm text-caption-sm text-on-surface-variant">收入</span>
          </div>
          <div className="flex items-center gap-2">
            <div className="w-3 h-3 rounded-sm bg-error" />
            <span className="font-caption-sm text-caption-sm text-on-surface-variant">支出</span>
          </div>
        </div>
      </div>

      {/* Account breakdown */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
        <h3 className="font-headline-md text-headline-md text-text-primary mb-6">账户概览</h3>
        <div className="space-y-3">
          {ACCOUNTS.map((acc) => (
            <div key={acc.id} className="flex items-center justify-between py-2 border-b border-divider last:border-0">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-surface-container flex items-center justify-center">
                  <span className="material-symbols-outlined text-sm text-on-surface-variant" style={{ fontVariationSettings: "'FILL' 1" }}>
                    {acc.icon}
                  </span>
                </div>
                <div>
                  <p className="font-body-md text-body-md text-text-primary">{acc.name}</p>
                  <p className="font-caption-sm text-caption-sm text-on-surface-variant">{acc.type}</p>
                </div>
              </div>
              <p className={`font-label-mono text-label-mono ${acc.balance < 0 ? 'text-error' : 'text-text-primary'}`}>
                ¥{formatMoney(acc.balance)}
              </p>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
