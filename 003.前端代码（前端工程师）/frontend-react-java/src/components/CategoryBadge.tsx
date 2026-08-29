import type { Category } from '../lib/finance-types'

interface CategoryBadgeProps {
  category: Category
  size?: 'sm' | 'md'
}

// Solid hex values used for both bg (with 20% alpha via 8-digit hex) and icon text.
const COLOR_MAP: Record<Category['colorToken'], string> = {
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

export function CategoryBadge({ category, size = 'md' }: CategoryBadgeProps) {
  const sizeClasses = size === 'sm' ? 'w-10 h-10' : 'w-10 h-10'
  const iconSize = size === 'sm' ? '20px' : '20px'
  const color = COLOR_MAP[category.colorToken]
  // Append 33 hex (= 51/255 ≈ 20% alpha) so bg is 20% opacity but icon stays full color.
  const bg = `${color}33`

  return (
    <div
      className={`${sizeClasses} rounded-full flex items-center justify-center shrink-0`}
      style={{ backgroundColor: bg }}
    >
      <span
        className="material-symbols-outlined"
        style={{ fontSize: iconSize, color }}
      >
        {category.icon}
      </span>
    </div>
  )
}