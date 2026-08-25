import React, { useState, useMemo } from 'react'
import dayjs from 'dayjs'
import { useRecordStore } from '../../stores/useRecordStore'
import { useAppStore } from '../../stores/useAppStore'
import MonthPicker from '../../components/MonthPicker'
import EmptyState from '../../components/EmptyState'
import CategoryIcon from '../../components/CategoryIcon'
import AmountDisplay from '../../components/AmountDisplay'
import QuickRecord from '../../features/QuickRecord'
import { Plus } from '../../components/Icons'
import { RecordWithDetails } from '../../types'

const HomePage: React.FC = () => {
  const { records } = useRecordStore()
  const { currentMonth, setCurrentMonth } = useAppStore()
  const [isRecordOpen, setIsRecordOpen] = useState(false)

  const monthlyRecords = useMemo(() => {
    return records
      .filter((r) => r.recordDate.startsWith(currentMonth))
      .sort((a, b) => b.recordDate.localeCompare(a.recordDate) || b.createdAt - a.createdAt)
  }, [records, currentMonth])

  const totals = useMemo(() => {
    return monthlyRecords.reduce(
      (acc, r) => {
        if (r.type === 'expense') acc.expense += r.amount
        else acc.income += r.amount
        return acc
      },
      { expense: 0, income: 0 }
    )
  }, [monthlyRecords])

  const groupedByDate = useMemo(() => {
    const groups: Record<string, RecordWithDetails[]> = {}
    monthlyRecords.forEach((r) => {
      if (!groups[r.recordDate]) groups[r.recordDate] = []
      groups[r.recordDate].push(r)
    })
    return groups
  }, [monthlyRecords])

  return (
    <div className="relative min-h-full">
      <header className="sticky top-0 z-10 bg-[var(--color-bg-page)] px-4 pt-4">
        <div className="flex items-center justify-between">
          <h1 className="text-xl font-bold text-[var(--color-text-primary)]">轻账</h1>
        </div>
        <MonthPicker value={currentMonth} onChange={setCurrentMonth} />
      </header>

      <div className="px-4 pb-4">
        <div className="mb-4 grid grid-cols-2 gap-3">
          <div className="rounded-2xl bg-gradient-to-br from-[#fee2e2] to-[#fecaca] p-4 dark:from-red-900/30 dark:to-red-900/20">
            <div className="mb-1 text-sm text-red-700 dark:text-red-300">本月支出</div>
            <AmountDisplay amount={totals.expense} type="expense" className="text-2xl" />
          </div>
          <div className="rounded-2xl bg-gradient-to-br from-[#d1fae5] to-[#a7f3d0] p-4 dark:from-green-900/30 dark:to-green-900/20">
            <div className="mb-1 text-sm text-green-700 dark:text-green-300">本月收入</div>
            <AmountDisplay amount={totals.income} type="income" className="text-2xl" />
          </div>
        </div>

        {monthlyRecords.length === 0 ? (
          <EmptyState />
        ) : (
          <div className="space-y-4">
            {Object.entries(groupedByDate).map(([date, items]) => (
              <div key={date}>
                <div className="mb-2 flex items-center justify-between px-1">
                  <span className="text-sm font-medium text-[var(--color-text-secondary)]">
                    {dayjs(date).format('M月D日')} {dayjs(date).format('ddd')}
                  </span>
                  <span className="text-xs text-[var(--color-text-secondary)]">{items.length}笔</span>
                </div>
                <div className="rounded-2xl bg-[var(--color-bg-card)] p-2 shadow-sm">
                  {items.map((record) => (
                    <div
                      key={record.id}
                      className="flex items-center justify-between px-3 py-3"
                    >
                      <div className="flex items-center gap-3">
                        <CategoryIcon category={record.category} size="sm" />
                        <div>
                          <div className="text-sm font-medium text-[var(--color-text-primary)]">
                            {record.category.name}
                          </div>
                          {record.note && (
                            <div className="text-xs text-[var(--color-text-secondary)]">{record.note}</div>
                          )}
                        </div>
                      </div>
                      <AmountDisplay amount={record.amount} type={record.type} />
                    </div>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <button
        onClick={() => setIsRecordOpen(true)}
        className="fixed bottom-20 right-4 z-30 flex h-14 w-14 items-center justify-center rounded-full bg-[var(--color-primary)] text-white shadow-lg transition-transform active:scale-95"
      >
        <Plus size={28} />
      </button>

      <QuickRecord isOpen={isRecordOpen} onClose={() => setIsRecordOpen(false)} />
    </div>
  )
}

export default HomePage
