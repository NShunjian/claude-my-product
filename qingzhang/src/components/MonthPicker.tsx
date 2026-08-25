import React from 'react'
import dayjs from 'dayjs'

interface MonthPickerProps {
  value: string
  onChange: (value: string) => void
}

const MonthPicker: React.FC<MonthPickerProps> = ({ value, onChange }) => {
  const handlePrev = () => {
    onChange(dayjs(value + '-01').subtract(1, 'month').format('YYYY-MM'))
  }

  const handleNext = () => {
    onChange(dayjs(value + '-01').add(1, 'month').format('YYYY-MM'))
  }

  return (
    <div className="flex items-center justify-center gap-4 py-3">
      <button
        onClick={handlePrev}
        className="rounded-full p-1 text-[var(--color-text-secondary)] transition-colors hover:bg-[var(--color-primary-light)] hover:text-[var(--color-primary)]"
      >
        ◀
      </button>
      <span className="min-w-[100px] text-center text-lg font-semibold text-[var(--color-text-primary)]">
        {dayjs(value + '-01').format('YYYY年M月')}
      </span>
      <button
        onClick={handleNext}
        className="rounded-full p-1 text-[var(--color-text-secondary)] transition-colors hover:bg-[var(--color-primary-light)] hover:text-[var(--color-primary)]"
      >
        ▶
      </button>
    </div>
  )
}

export default MonthPicker
