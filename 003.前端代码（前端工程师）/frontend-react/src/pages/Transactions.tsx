import { useMemo, useState } from 'react'
import { usePageTitle } from '../components/PageTitleContext'
import { ACCOUNTS } from '../data/accounts'
import { TRANSACTIONS } from '../data/transactions'
import { EXPENSE_CATEGORIES, INCOME_CATEGORIES } from '../data/categories'
import { TransactionRow } from '../components/TransactionRow'

function findAccount(id: string) {
  return ACCOUNTS.find((a) => a.id === id)
}

export function Transactions() {
  usePageTitle('全部交易')
  const [filterMonth, setFilterMonth] = useState<string>('2026-08')
  const [filterCategory, setFilterCategory] = useState<string>('all')

  const allCategories = useMemo(
    () => [...EXPENSE_CATEGORIES, ...INCOME_CATEGORIES],
    [],
  )

  const filteredTxns = useMemo(() => {
    return TRANSACTIONS.filter((t) => {
      if (filterCategory !== 'all' && t.categoryId !== filterCategory) return false
      if (!t.date.startsWith(filterMonth)) return false
      return true
    }).sort((a, b) => (a.date < b.date ? 1 : -1))
  }, [filterMonth, filterCategory])

  return (
    <div className="space-y-6">
      {/* Filters */}
      <div className="bg-bg-card rounded-xl border border-divider p-4">
        <h2 className="font-headline-md text-headline-md text-text-primary mb-4">筛选</h2>
        <div className="flex flex-wrap gap-3">
          <select
            className="bg-surface-container-lowest border border-outline-variant text-text-primary text-body-md font-body-md rounded-lg py-2 pl-3 pr-8 focus:border-primary focus:ring-0 cursor-pointer"
            value={filterMonth}
            onChange={(e) => setFilterMonth(e.target.value)}
          >
            <option value="2026-08">2026年 8月</option>
            <option value="2026-07">2026年 7月</option>
            <option value="2026-06">2026年 6月</option>
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
        </div>
      </div>

      {/* Transaction list */}
      <div className="bg-bg-card rounded-xl border border-divider p-4">
        {filteredTxns.length === 0 ? (
          <p className="text-on-surface-variant font-body-md text-body-md text-center py-12">
            暂无交易记录
          </p>
        ) : (
          <div>
            {filteredTxns.map((txn) => (
              <TransactionRow
                key={txn.id}
                transaction={txn}
                account={findAccount(txn.accountId)}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  )
}
