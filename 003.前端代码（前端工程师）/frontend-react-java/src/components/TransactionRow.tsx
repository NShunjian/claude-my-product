import type { Transaction, Account, Category, TransactionType } from '../lib/finance-types'
import { CategoryBadge } from './CategoryBadge'
import { useLanguage } from '../i18n/LanguageContext'

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

/**
 * expense → "-¥"  income → "+¥"  transfer → "¥"（中性,不暗示方向,因为转账是两个账户互相抵消）
 */
function formatAmount(amount: number, type: TransactionType): string {
  const sign = type === 'expense' ? '-' : type === 'income' ? '+' : ''
  return `${sign}¥${new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Math.abs(amount))}`
}

/** 从 ISO 字符串取 HH:MM(本地时区)。无效返回空串。 */
function formatHHMM(iso: string | undefined): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${pad(d.getHours())}:${pad(d.getMinutes())}`
}

/** 从 ISO 字符串取本地 YYYY-MM-DD。无效返回空串。 */
function formatYMD(iso: string | undefined): string {
  if (!iso) return ''
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return ''
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`
}

export function TransactionRow({
  transaction,
  account,
  categories,
  variant = 'compact',
}: TransactionRowProps) {
  const category = findCategory(categories, transaction.categoryId)
  const isComfortable = variant === 'comfortable'
  const { t } = useLanguage()
  const time = formatHHMM(transaction.createdAt)
  const dateLabel = formatYMD(transaction.createdAt)

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

      <div className="flex flex-col items-end shrink-0">
        <span
          className={`font-label-mono text-label-mono ${
            transaction.type === 'expense' ? 'text-error' : 'text-secondary'
          }`}
        >
          {formatAmount(transaction.amount, transaction.type)}
        </span>
        {(dateLabel || time) && (
          <span className="font-caption-sm text-caption-sm text-on-surface-variant whitespace-nowrap">
            {t('transactions.recordTime')}: {dateLabel}
            {dateLabel && time ? ' ' : ''}
            {time}
          </span>
        )}
      </div>
    </div>
  )
}