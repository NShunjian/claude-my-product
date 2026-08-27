import type { Transaction, Account, Category } from '../lib/finance-types'
import { CategoryBadge } from './CategoryBadge'

interface TransactionRowProps {
  transaction: Transaction
  account: Account | undefined
  /** 全部分类数组，用于按 categoryId 查找展示名/图标/颜色。父组件负责加载并合并 expense+income。 */
  categories: Category[]
  /** 'compact' = Home/列表中嵌入用（py 较小、gap-3）
   *  'comfortable' = 独立交易列表页（p-4、gap-4、hover 高亮） */
  variant?: 'compact' | 'comfortable'
}

function findCategory(categories: Category[], id: string): Category | undefined {
  return categories.find((c) => c.id === id)
}

function formatAmount(amount: number, type: 'expense' | 'income'): string {
  const sign = type === 'expense' ? '-' : '+'
  return `${sign}¥${new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Math.abs(amount))}`
}

export function TransactionRow({
  transaction,
  account,
  categories,
  variant = 'compact',
}: TransactionRowProps) {
  const category = findCategory(categories, transaction.categoryId)
  const isComfortable = variant === 'comfortable'

  const containerClass = isComfortable
    ? 'flex items-center justify-between p-4 border-b border-divider hover:bg-surface-container-low transition-colors cursor-pointer last:border-0'
    : 'flex items-center gap-3 py-3 border-b border-divider last:border-0'

  return (
    <div className={containerClass}>
      <div className={isComfortable ? 'flex items-center gap-4' : 'contents'}>
        {category && <CategoryBadge category={category} size="sm" />}

        <div className={isComfortable ? '' : 'flex-1 min-w-0'}>
          <p className="font-body-md text-body-md text-text-primary font-medium truncate">
            {transaction.note || (category?.name ?? '')}
          </p>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant truncate">
            {category?.name}
            {account && <span> · {account.name}</span>}
          </p>
        </div>
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