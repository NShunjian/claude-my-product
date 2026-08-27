import { useMemo, useState } from 'react'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { ACCOUNTS } from '../data/accounts'
import { TRANSACTIONS } from '../data/transactions'
import { EXPENSE_CATEGORIES, INCOME_CATEGORIES } from '../data/categories'
import { TransactionRow } from '../components/TransactionRow'

function findAccount(id: string) {
  return ACCOUNTS.find((a) => a.id === id)
}

const WEEKDAYS = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Math.abs(amount))
}

function formatMonth(month: string): string {
  const [y, m] = month.split('-')
  return `${y}年 ${parseInt(m, 10)}月`
}

function formatDayWithWeekday(iso: string): string {
  const d = new Date(iso)
  return `${d.getMonth() + 1}月${d.getDate()}日，${WEEKDAYS[d.getDay()]}`
}

export function Transactions() {
  usePageTitle('全部交易')
  usePageBack('/', '首页')

  const [filterMonth, setFilterMonth] = useState<string>('2026-08')
  const [filterCategory, setFilterCategory] = useState<string>('all')
  const [filterAccount, setFilterAccount] = useState<string>('all')

  const allCategories = useMemo(
    () => [...EXPENSE_CATEGORIES, ...INCOME_CATEGORIES],
    [],
  )

  const filteredTxns = useMemo(() => {
    return TRANSACTIONS.filter((t) => {
      if (filterCategory !== 'all' && t.categoryId !== filterCategory) return false
      if (filterAccount !== 'all' && t.accountId !== filterAccount) return false
      if (!t.date.startsWith(filterMonth)) return false
      return true
    }).sort((a, b) => (a.date < b.date ? 1 : -1))
  }, [filterMonth, filterCategory, filterAccount])

  const { income, expense } = useMemo(() => {
    let inc = 0
    let exp = 0
    for (const t of filteredTxns) {
      if (t.type === 'income') inc += t.amount
      else exp += t.amount
    }
    return { income: inc, expense: exp }
  }, [filteredTxns])
  const net = income - expense

  const groupedTxns = useMemo(() => {
    const groups = new Map<string, typeof filteredTxns>()
    for (const t of filteredTxns) {
      const arr = groups.get(t.date) ?? []
      arr.push(t)
      groups.set(t.date, arr)
    }
    return Array.from(groups.entries()).map(([date, txns]) => {
      const groupNet = txns.reduce(
        (s, t) => s + (t.type === 'income' ? t.amount : -t.amount),
        0,
      )
      return { date, txns, net: groupNet, label: formatDayWithWeekday(date) }
    })
  }, [filteredTxns])

  return (
    <div className="space-y-6">
      {/* Bento grid: filter card + summary card (50/50 split) */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {/* Filter card */}
        <div className="bg-bg-card rounded-xl border border-divider p-4 flex flex-col justify-center">
          <h2 className="font-headline-md text-headline-md text-text-primary mb-4">筛选</h2>
          <div className="flex flex-wrap gap-3">
            <select
              className="bg-surface-container-lowest border border-outline-variant text-text-primary text-body-md font-body-md rounded-lg py-2 pl-3 pr-8 focus:border-primary focus:ring-0 cursor-pointer"
              value={filterMonth}
              onChange={(e) => setFilterMonth(e.target.value)}
            >
              <option value="2026-08">{formatMonth('2026-08')}</option>
              <option value="2026-07">{formatMonth('2026-07')}</option>
              <option value="2026-06">{formatMonth('2026-06')}</option>
            </select>

            <select
              className="bg-surface-container-lowest border border-outline-variant text-text-primary text-body-md font-body-md rounded-lg py-2 pl-3 pr-8 focus:border-primary focus:ring-0 cursor-pointer"
              value={filterCategory}
              onChange={(e) => setFilterCategory(e.target.value)}
            >
              <option value="all">所有分类</option>
              {allCategories.map((cat) => (
                <option key={cat.id} value={cat.id}>
                  {cat.name}
                </option>
              ))}
            </select>

            <select
              className="bg-surface-container-lowest border border-outline-variant text-text-primary text-body-md font-body-md rounded-lg py-2 pl-3 pr-8 focus:border-primary focus:ring-0 cursor-pointer"
              value={filterAccount}
              onChange={(e) => setFilterAccount(e.target.value)}
            >
              <option value="all">所有账户</option>
              {ACCOUNTS.map((acct) => (
                <option key={acct.id} value={acct.id}>
                  {acct.name}
                </option>
              ))}
            </select>
          </div>
        </div>

        {/* Summary card */}
        <div className="bg-primary text-on-primary rounded-xl p-4 flex flex-col justify-center relative overflow-hidden">
          <div className="absolute -right-10 -top-10 w-32 h-32 bg-primary-light opacity-10 rounded-full blur-2xl" />
          <span className="font-caption-sm text-caption-sm text-primary-light mb-1">
            当月结余
          </span>
          <span className="font-label-mono text-label-mono text-2xl">
            ¥ {formatMoney(net)}
          </span>
          <div className="flex justify-between mt-4 font-body-md text-body-md">
            <div className="flex flex-col">
              <span className="text-primary-light">收入</span>
              <span className="font-label-mono text-label-mono">+¥ {formatMoney(income)}</span>
            </div>
            <div className="flex flex-col text-right">
              <span className="text-primary-light">支出</span>
              <span className="font-label-mono text-label-mono">-¥ {formatMoney(expense)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Transaction list grouped by date */}
      <div className="bg-bg-card rounded-xl border border-divider overflow-hidden">
        {filteredTxns.length === 0 ? (
          <p className="text-on-surface-variant font-body-md text-body-md text-center py-12">
            暂无交易记录
          </p>
        ) : (
          <div className="flex flex-col">
            {groupedTxns.map((group, idx) => (
              <div key={group.date} className={idx === 0 ? '' : 'mt-2'}>
                {/* Date header */}
                <div className="px-4 py-3 bg-surface-container-low border-b border-divider flex justify-between items-center">
                  <span className="font-headline-md text-headline-md text-text-primary text-sm">
                    {group.label}
                  </span>
                  <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                    {group.net >= 0 ? '+' : '-'}¥ {formatMoney(group.net)}
                  </span>
                </div>

                {/* Tx items */}
                <div className="flex flex-col">
                  {group.txns.map((txn) => (
                    <TransactionRow
                      key={txn.id}
                      transaction={txn}
                      account={findAccount(txn.accountId)}
                      variant="comfortable"
                    />
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {/* Load more */}
      <div className="mt-8 flex justify-center">
        <button
          type="button"
          className="px-6 py-2 border border-divider rounded-full font-body-md text-body-md text-on-surface-variant hover:bg-surface-container-low hover:text-text-primary transition-colors"
        >
          加载更多
        </button>
      </div>
    </div>
  )
}