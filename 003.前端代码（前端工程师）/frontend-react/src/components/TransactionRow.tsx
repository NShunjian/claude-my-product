import type { Transaction } from '../data/transactions'
import { EXPENSE_CATEGORIES, INCOME_CATEGORIES, type Category } from '../data/categories'
import type { Account } from '../data/accounts'
import { CategoryBadge } from './CategoryBadge'

interface TransactionRowProps {
  transaction: Transaction
  account: Account | undefined
}

function findCategory(id: string): Category | undefined {
  return [...EXPENSE_CATEGORIES, ...INCOME_CATEGORIES].find((c) => c.id === id)
}

function formatAmount(amount: number, type: 'expense' | 'income'): string {
  const sign = type === 'expense' ? '-' : '+'
  return `${sign}¥${new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Math.abs(amount))}`
}

export function TransactionRow({ transaction, account }: TransactionRowProps) {
  const category = findCategory(transaction.categoryId)

  return (
    <div className="flex items-center gap-3 py-3 border-b border-divider last:border-0">
      {category && <CategoryBadge category={category} size="sm" />}

      <div className="flex-1 min-w-0">
        <p className="font-headline-md text-headline-md text-text-primary truncate">
          {transaction.note}
        </p>
        <p className="font-caption-sm text-caption-sm text-on-surface-variant truncate">
          {category?.name}
          {account && <span> · {account.name}</span>}
        </p>
      </div>

      <span
        className={`font-label-mono text-label-mono shrink-0 ${
          transaction.type === 'expense' ? 'text-error' : 'text-secondary'
        }`}
      >
        {formatAmount(transaction.amount, transaction.type)}
      </span>
    </div>
  )
}