import { useMemo } from 'react'
import { usePageTitle } from '../components/PageTitleContext'
import { TRANSACTIONS } from '../data/transactions'
import { EXPENSE_CATEGORIES, INCOME_CATEGORIES } from '../data/categories'
import { ACCOUNTS } from '../data/accounts'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

const COLOR_MAP: Record<string, string> = {
  'cat-pink': '#ED64A6',
  'cat-blue': '#4299E1',
  'cat-purple': '#805AD5',
  'cat-teal': '#319795',
  'cat-brown': '#8B6E4E',
  secondary: '#006d40',
  outline: '#727782',
}

export function ReportMonthly() {
  usePageTitle('报表')

  const monthTxns = useMemo(() => {
    return TRANSACTIONS.filter((t) => t.date.startsWith('2026-08'))
  }, [])

  const totalIncome = useMemo(
    () => monthTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0),
    [monthTxns],
  )

  const totalExpense = useMemo(
    () => monthTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [monthTxns],
  )

  const netSavings = totalIncome - totalExpense

  const expenseByCategory = useMemo(() => {
    return EXPENSE_CATEGORIES.map((cat) => ({
      ...cat,
      total: monthTxns
        .filter((t) => t.type === 'expense' && t.categoryId === cat.id)
        .reduce((s, t) => s + t.amount, 0),
    }))
      .filter((c) => c.total > 0)
      .sort((a, b) => b.total - a.total)
  }, [monthTxns])

  const incomeByCategory = useMemo(() => {
    return INCOME_CATEGORIES.map((cat) => ({
      ...cat,
      total: monthTxns
        .filter((t) => t.type === 'income' && t.categoryId === cat.id)
        .reduce((s, t) => s + t.amount, 0),
    }))
      .filter((c) => c.total > 0)
      .sort((a, b) => b.total - a.total)
  }, [monthTxns])

  const maxCat = Math.max(
    ...expenseByCategory.map((c) => c.total),
    ...incomeByCategory.map((c) => c.total),
  )

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex justify-between items-end">
        <div>
          <h2 className="font-display-lg text-display-lg text-text-primary mb-1">报表</h2>
          <div className="flex items-center gap-2 text-on-surface-variant font-headline-md text-headline-md cursor-pointer hover:text-primary transition-colors">
            <span>8月 2026</span>
            <span className="material-symbols-outlined text-sm">expand_more</span>
          </div>
        </div>
        <div className="flex gap-2">
          <a
            href="/reports/monthly"
            className="px-4 py-2 bg-primary-light text-primary font-body-md text-body-md rounded-lg font-semibold"
          >
            月报
          </a>
          <a
            href="/reports/yearly"
            className="px-4 py-2 bg-surface-container text-on-surface-variant font-body-md text-body-md rounded-lg hover:bg-surface-container-high transition-colors"
          >
            年报
          </a>
        </div>
      </div>

      {/* Summary cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1">总收入</p>
          <p className="font-label-mono text-label-mono text-secondary">
            +¥{formatMoney(totalIncome)}
          </p>
        </div>
        <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1">总支出</p>
          <p className="font-label-mono text-label-mono text-error">
            -¥{formatMoney(totalExpense)}
          </p>
        </div>
        <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mb-1">净结余</p>
          <p className={`font-label-mono text-label-mono ${netSavings >= 0 ? 'text-primary' : 'text-error'}`}>
            {netSavings >= 0 ? '+' : '-'}¥{formatMoney(Math.abs(netSavings))}
          </p>
        </div>
      </div>

      {/* Expense breakdown */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
        <h3 className="font-headline-md text-headline-md text-text-primary mb-6">支出构成</h3>
        {expenseByCategory.length === 0 ? (
          <p className="text-on-surface-variant text-center py-8">暂无支出记录</p>
        ) : (
          <div className="space-y-5">
            {expenseByCategory.map((cat) => {
              const color = COLOR_MAP[cat.colorToken]
              const pct = maxCat > 0 ? (cat.total / maxCat) * 100 : 0
              return (
                <div key={cat.id}>
                  <div className="flex justify-between items-center mb-2">
                    <div className="flex items-center gap-2">
                      <span
                        className="material-symbols-outlined text-lg"
                        style={{ color, fontVariationSettings: "'FILL' 1" }}
                      >
                        {cat.icon}
                      </span>
                      <span className="font-body-md text-body-md text-text-primary">{cat.name}</span>
                    </div>
                    <div className="text-right">
                      <span className="font-body-md text-body-md text-text-primary">
                        ¥{formatMoney(cat.total)}
                      </span>
                      <span className="font-caption-sm text-caption-sm text-on-surface-variant ml-2">
                        {((cat.total / totalExpense) * 100).toFixed(1)}%
                      </span>
                    </div>
                  </div>
                  <div className="h-2 bg-surface-container rounded-full overflow-hidden">
                    <div
                      className="h-full rounded-full transition-all"
                      style={{ width: `${pct}%`, backgroundColor: color }}
                    />
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Income breakdown */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
        <h3 className="font-headline-md text-headline-md text-text-primary mb-6">收入构成</h3>
        {incomeByCategory.length === 0 ? (
          <p className="text-on-surface-variant text-center py-8">暂无收入记录</p>
        ) : (
          <div className="space-y-5">
            {incomeByCategory.map((cat) => {
              const color = COLOR_MAP[cat.colorToken]
              const pct = maxCat > 0 ? (cat.total / maxCat) * 100 : 0
              return (
                <div key={cat.id}>
                  <div className="flex justify-between items-center mb-2">
                    <div className="flex items-center gap-2">
                      <span
                        className="material-symbols-outlined text-lg"
                        style={{ color, fontVariationSettings: "'FILL' 1" }}
                      >
                        {cat.icon}
                      </span>
                      <span className="font-body-md text-body-md text-text-primary">{cat.name}</span>
                    </div>
                    <div className="text-right">
                      <span className="font-body-md text-body-md text-text-primary">
                        ¥{formatMoney(cat.total)}
                      </span>
                      <span className="font-caption-sm text-caption-sm text-on-surface-variant ml-2">
                        {((cat.total / totalIncome) * 100).toFixed(1)}%
                      </span>
                    </div>
                  </div>
                  <div className="h-2 bg-surface-container rounded-full overflow-hidden">
                    <div
                      className="h-full rounded-full transition-all"
                      style={{ width: `${pct}%`, backgroundColor: color }}
                    />
                  </div>
                </div>
              )
            })}
          </div>
        )}
      </div>

      {/* Account breakdown */}
      <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
        <h3 className="font-headline-md text-headline-md text-text-primary mb-6">账户概览</h3>
        <div className="space-y-3">
          {ACCOUNTS.map((acc) => {
            const color = COLOR_MAP[acc.colorToken] ?? '#727782'
            return (
              <div key={acc.id} className="flex items-center justify-between py-2 border-b border-divider last:border-0">
                <div className="flex items-center gap-3">
                  <div
                    className="w-8 h-8 rounded-full flex items-center justify-center"
                    style={{ backgroundColor: color, opacity: 0.2 }}
                  >
                    <span
                      className="material-symbols-outlined text-sm"
                      style={{ color, fontVariationSettings: "'FILL' 1" }}
                    >
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
            )
          })}
        </div>
      </div>
    </div>
  )
}
