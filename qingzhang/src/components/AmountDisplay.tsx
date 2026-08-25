import React from 'react'

interface AmountDisplayProps {
  amount: number
  type?: 'expense' | 'income' | 'default'
  className?: string
  prefix?: string
}

const AmountDisplay: React.FC<AmountDisplayProps> = ({ amount, type = 'default', className = '', prefix = '¥' }) => {
  const colorClass =
    type === 'expense' ? 'text-[var(--color-danger)]' : type === 'income' ? 'text-[var(--color-success)]' : 'text-[var(--color-text-primary)]'

  const sign = type === 'expense' ? '-' : type === 'income' ? '+' : ''

  return (
    <span className={`font-mono font-semibold tabular-nums ${colorClass} ${className}`}>
      {sign}
      {prefix}
      {amount.toFixed(2)}
    </span>
  )
}

export default AmountDisplay
