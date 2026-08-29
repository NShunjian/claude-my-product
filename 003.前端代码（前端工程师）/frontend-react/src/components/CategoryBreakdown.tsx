import type { Transaction, Category } from '../lib/finance-types'

interface CategoryBreakdownProps {
  title: string
  categories: Category[]
  transactions: Transaction[]
  type: 'expense' | 'income'
  totalAmount: number
}

const COLORS: Record<Category['colorToken'], string> = {
  'cat-pink': '#ED64A6',
  'cat-blue': '#4299E1',
  'cat-purple': '#805AD5',
  'cat-teal': '#319795',
  'cat-brown': '#8B6E4E',
  'cat-orange': '#F59E0B',
  'cat-cyan': '#06B6D4',
  'cat-indigo': '#6366F1',
  secondary: '#006d40',
  outline: '#727782',
}

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

export function CategoryBreakdown({
  title,
  categories,
  transactions,
  type,
  totalAmount,
}: CategoryBreakdownProps) {
  // 遍历所有分类,按本月金额降序;金额为 0 的排在底部仍显示
  const rows = [...categories]
    .map((cat) => ({
      cat,
      total: transactions
        .filter((t) => t.type === type && t.categoryId === cat.id)
        .reduce((s, t) => s + t.amount, 0),
    }))
    .sort((a, b) => b.total - a.total)

  return (
    <div className="bg-bg-card rounded-xl border border-divider p-6 shadow-sm">
      <h3 className="font-headline-md text-headline-md text-text-primary mb-4">{title}</h3>
      <div className="space-y-4">
        {rows.map(({ cat, total: catTotal }) => {
          const pct = totalAmount > 0 ? (catTotal / totalAmount) * 100 : 0
          const color = COLORS[cat.colorToken] ?? '#727782'

          return (
            <div key={cat.id}>
              <div className="flex justify-between mb-1">
                <div className="flex items-center gap-2">
                  <span
                    className="material-symbols-outlined text-sm"
                    style={{ color, fontVariationSettings: "'FILL' 1" }}
                  >
                    {cat.icon}
                  </span>
                  <span className="font-body-md text-body-md text-text-primary">{cat.name}</span>
                </div>
                <span className="font-body-md text-body-md text-on-surface-variant">
                  ¥{formatMoney(catTotal)}
                </span>
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
    </div>
  )
}
