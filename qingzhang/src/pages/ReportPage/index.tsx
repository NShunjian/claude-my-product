import React, { useMemo } from 'react'
import dayjs from 'dayjs'
import { useRecordStore } from '../../stores/useRecordStore'
import { useAppStore } from '../../stores/useAppStore'
import MonthPicker from '../../components/MonthPicker'
import AmountDisplay from '../../components/AmountDisplay'
import {
  PieChart,
  Pie,
  Cell,
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  BarChart,
  Bar,
} from 'recharts'
import { CATEGORY_COLORS } from '../../constants/theme'

const ReportPage: React.FC = () => {
  const { records } = useRecordStore()
  const { currentMonth, setCurrentMonth } = useAppStore()

  const monthlyRecords = useMemo(
    () => records.filter((r) => r.recordDate.startsWith(currentMonth)),
    [records, currentMonth]
  )

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

  const dailyData = useMemo(() => {
    const days = dayjs(currentMonth + '-01').daysInMonth()
    const data: { day: string; expense: number; income: number }[] = []
    for (let i = 1; i <= days; i++) {
      const day = i.toString().padStart(2, '0')
      const dateStr = `${currentMonth}-${day}`
      const dayRecords = monthlyRecords.filter((r) => r.recordDate === dateStr)
      data.push({
        day: `${i}日`,
        expense: dayRecords
          .filter((r) => r.type === 'expense')
          .reduce((sum, r) => sum + r.amount, 0),
        income: dayRecords
          .filter((r) => r.type === 'income')
          .reduce((sum, r) => sum + r.amount, 0),
      })
    }
    return data
  }, [monthlyRecords, currentMonth])

  const categoryData = useMemo(() => {
    const map: Record<string, number> = {}
    monthlyRecords
      .filter((r) => r.type === 'expense')
      .forEach((r) => {
        map[r.category.name] = (map[r.category.name] || 0) + r.amount
      })
    return Object.entries(map)
      .map(([name, value]) => ({ name, value }))
      .sort((a, b) => b.value - a.value)
  }, [monthlyRecords])

  const comparisonData = useMemo(() => {
    const data: { month: string; expense: number; income: number }[] = []
    for (let i = 5; i >= 0; i--) {
      const month = dayjs(currentMonth + '-01').subtract(i, 'month').format('YYYY-MM')
      const monthRecords = records.filter((r) => r.recordDate.startsWith(month))
      data.push({
        month: dayjs(month + '-01').format('M月'),
        expense: monthRecords
          .filter((r) => r.type === 'expense')
          .reduce((sum, r) => sum + r.amount, 0),
        income: monthRecords
          .filter((r) => r.type === 'income')
          .reduce((sum, r) => sum + r.amount, 0),
      })
    }
    return data
  }, [records, currentMonth])

  return (
    <div className="min-h-full pb-20">
      <header className="sticky top-0 z-10 bg-[var(--color-bg-page)] px-4 pt-4">
        <h1 className="mb-2 text-center text-xl font-bold text-[var(--color-text-primary)]">报表</h1>
        <MonthPicker value={currentMonth} onChange={setCurrentMonth} />
      </header>

      <div className="space-y-4 px-4">
        {/* 月度总览 */}
        <div className="rounded-2xl bg-[var(--color-bg-card)] p-4 shadow-sm">
          <h3 className="mb-3 text-base font-semibold text-[var(--color-text-primary)]">月度总览</h3>
          <div className="grid grid-cols-3 gap-3">
            <div>
              <div className="mb-1 text-xs text-[var(--color-text-secondary)]">支出</div>
              <AmountDisplay amount={totals.expense} type="expense" className="text-base" />
            </div>
            <div>
              <div className="mb-1 text-xs text-[var(--color-text-secondary)]">收入</div>
              <AmountDisplay amount={totals.income} type="income" className="text-base" />
            </div>
            <div>
              <div className="mb-1 text-xs text-[var(--color-text-secondary)]">结余</div>
              <AmountDisplay amount={totals.income - totals.expense} type="default" className="text-base" />
            </div>
          </div>
        </div>

        {/* 日收支趋势 */}
        <div className="rounded-2xl bg-[var(--color-bg-card)] p-4 shadow-sm">
          <h3 className="mb-3 text-base font-semibold text-[var(--color-text-primary)]">日收支趋势</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={dailyData}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--color-divider)" />
                <XAxis dataKey="day" tick={{ fontSize: 10 }} />
                <YAxis tick={{ fontSize: 10 }} />
                <Tooltip />
                <Line type="monotone" dataKey="expense" stroke={THEME_COLORS.danger} strokeWidth={2} dot={false} />
                <Line type="monotone" dataKey="income" stroke={THEME_COLORS.success} strokeWidth={2} dot={false} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>

        {/* 支出分类占比 */}
        <div className="rounded-2xl bg-[var(--color-bg-card)] p-4 shadow-sm">
          <h3 className="mb-3 text-base font-semibold text-[var(--color-text-primary)]">支出分类占比</h3>
          {categoryData.length === 0 ? (
            <div className="py-8 text-center text-sm text-[var(--color-text-secondary)]">暂无支出数据</div>
          ) : (
            <>
              <div className="h-64">
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={categoryData}
                      cx="50%"
                      cy="50%"
                      innerRadius={60}
                      outerRadius={80}
                      paddingAngle={2}
                      dataKey="value"
                    >
                      {categoryData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={CATEGORY_COLORS[entry.name] || '#A0AEC0'} />
                      ))}
                    </Pie>
                    <Tooltip />
                  </PieChart>
                </ResponsiveContainer>
              </div>
              <div className="mt-2 space-y-2">
                {categoryData.map((item) => (
                  <div key={item.name} className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <div
                        className="h-3 w-3 rounded-full"
                        style={{ backgroundColor: CATEGORY_COLORS[item.name] || '#A0AEC0' }}
                      />
                      <span className="text-sm text-[var(--color-text-primary)]">{item.name}</span>
                    </div>
                    <span className="text-sm text-[var(--color-text-secondary)]">¥{item.value.toFixed(2)}</span>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>

        {/* 月度对比 */}
        <div className="rounded-2xl bg-[var(--color-bg-card)] p-4 shadow-sm">
          <h3 className="mb-3 text-base font-semibold text-[var(--color-text-primary)]">近6月对比</h3>
          <div className="h-64">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={comparisonData}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--color-divider)" />
                <XAxis dataKey="month" tick={{ fontSize: 10 }} />
                <YAxis tick={{ fontSize: 10 }} />
                <Tooltip />
                <Bar dataKey="expense" fill={THEME_COLORS.danger} radius={[4, 4, 0, 0]} />
                <Bar dataKey="income" fill={THEME_COLORS.success} radius={[4, 4, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  )
}

const THEME_COLORS = {
  danger: '#E53E3E',
  success: '#38A169',
}

export default ReportPage
