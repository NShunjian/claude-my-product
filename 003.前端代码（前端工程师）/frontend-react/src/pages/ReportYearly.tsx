import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { TRANSACTIONS } from '../data/transactions'
import { EXPENSE_CATEGORIES } from '../data/categories'
import { DonutChart, type DonutSegment } from '../components/DonutChart'

// 年报专用配色（与原型一致）
const REPORT_PALETTE: Record<string, string> = {
  housing: '#3b82f6',
  food: '#f97316',
  transport: '#8b5cf6',
  shopping: '#ec4899',
  entertainment: '#06b6d4',
  medical: '#10b981',
  education: '#eab308',
  comm: '#94a3b8',
}

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('en-US', {
    minimumFractionDigits: 0,
    maximumFractionDigits: 2,
  }).format(Math.abs(amount))
}

export function ReportYearly() {
  usePageTitle('报表')
  usePageBack(null)

  const [filterYear] = useState('2026')

  // 全年交易
  const yearlyTxns = useMemo(
    () => TRANSACTIONS.filter((t) => t.date.startsWith(filterYear)),
    [filterYear],
  )

  const totalIncome = useMemo(
    () => yearlyTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0),
    [yearlyTxns],
  )
  const totalExpense = useMemo(
    () => yearlyTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [yearlyTxns],
  )
  const netSavings = totalIncome - totalExpense

  // 12 个月度收支数据（柱状图）
  const monthlyData = useMemo(() => {
    return Array.from({ length: 12 }, (_, i) => {
      const m = String(i + 1).padStart(2, '0')
      const monthTxns = yearlyTxns.filter((t) => t.date.slice(5, 7) === m)
      const income = monthTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0)
      const expense = monthTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0)
      return { month: i + 1, income, expense }
    })
  }, [yearlyTxns])

  // Y 轴上限：取最大值向上取整到 5000 的倍数
  const yAxisMax = useMemo(() => {
    const raw = Math.max(...monthlyData.map((d) => Math.max(d.income, d.expense)), 0)
    return Math.ceil(raw / 5000) * 5000 || 10000
  }, [monthlyData])

  // 支出构成（按分类汇总，按总额降序）
  const expenseByCategory = useMemo(() => {
    return EXPENSE_CATEGORIES.map((cat) => ({
      ...cat,
      total: yearlyTxns
        .filter((t) => t.type === 'expense' && t.categoryId === cat.id)
        .reduce((s, t) => s + t.amount, 0),
    }))
      .filter((c) => c.total > 0)
      .sort((a, b) => b.total - a.total)
  }, [yearlyTxns])

  // 环形图：取前 5 大支出分类（剩余归为"其他"以填充完整环）
  const donutSegments: DonutSegment[] = useMemo(() => {
    const top = expenseByCategory.slice(0, 5)
    const topTotal = top.reduce((s, x) => s + x.total, 0)
    const rest = Math.max(0, totalExpense - topTotal)
    const segs: DonutSegment[] = top.map((cat) => ({
      label: cat.name,
      value: cat.total,
      color: REPORT_PALETTE[cat.id] ?? '#94a3b8',
    }))
    if (rest > 0) {
      segs.push({ label: '其他', value: rest, color: '#E2E8F0' })
    }
    return segs
  }, [expenseByCategory, totalExpense])

  // 环形图下方分类列表（按原型展示前 2 项）
  const topCategories = expenseByCategory.slice(0, 2)

  const monthLabels = ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月']

  return (
    <div className="space-y-6">
      {/* 标题 + 年份选择 + 月报/年报 切换 */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md text-text-primary leading-none mb-1.5">
            年度统计
          </h2>
          <p className="font-body-md text-body-md text-on-surface-variant">{filterYear} 年</p>
        </div>
        <div className="flex items-center gap-3">
          {/* 年份选择器（白底 + 浅边框） */}
          <div className="flex items-center gap-2 px-4 py-2 rounded-xl bg-bg-card border border-divider">
            <button
              type="button"
              className="text-on-surface-variant hover:text-primary transition-colors"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
                chevron_left
              </span>
            </button>
            <span
              className="material-symbols-outlined text-primary"
              style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
            >
              calendar_month
            </span>
            <span className="font-body-md text-body-md font-medium text-text-primary min-w-[72px] text-center">
              {filterYear} 年
            </span>
            <button
              type="button"
              className="text-on-surface-variant hover:text-primary transition-colors"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
                chevron_right
              </span>
            </button>
          </div>

          {/* 月报/年报 切换（白底容器 + 白卡高亮） */}
          <div className="flex items-center p-1 rounded-xl bg-surface-container border border-transparent">
            <Link
              to="/reports/monthly"
              className="px-5 py-1.5 font-body-md text-body-md font-medium rounded-lg transition-colors text-on-surface-variant hover:text-primary"
            >
              月报
            </Link>
            <Link
              to="/reports/yearly"
              className="px-5 py-1.5 font-body-md text-body-md font-medium rounded-lg transition-colors bg-bg-card text-primary shadow-sm"
            >
              年报
            </Link>
          </div>
        </div>
      </div>

      {/* 3 个 KPI 卡片（年度结余 / 年度总收入 / 年度总支出） */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        {/* 年度结余 */}
        <div className="bento-item bg-bg-card md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-on-surface-variant">
            <span
              className="w-7 h-7 rounded-full flex items-center justify-center"
              style={{ backgroundColor: 'rgb(43 108 176 / 0.1)' }}
            >
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '16px', color: '#005394', fontVariationSettings: "'FILL' 1" }}
              >
                account_balance
              </span>
            </span>
            <span className="font-body-md text-body-md">年度结余</span>
          </div>
          <p
            className={`font-label-mono text-label-mono text-3xl font-bold ${
              netSavings >= 0 ? 'text-primary' : 'text-error'
            }`}
          >
            ${formatMoney(netSavings)}
          </p>
        </div>

        {/* 年度总收入 */}
        <div className="bento-item bg-income-card border-primary-soft md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-primary">
            <span
              className="w-7 h-7 rounded-full flex items-center justify-center"
              style={{ backgroundColor: 'rgb(16 185 129 / 0.15)' }}
            >
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '16px', color: '#10b981', fontVariationSettings: "'FILL' 1" }}
              >
                trending_down
              </span>
            </span>
            <span className="font-body-md text-body-md font-medium">年度总收入</span>
          </div>
          <p className="font-label-mono text-label-mono text-primary text-3xl font-bold">
            +${formatMoney(totalIncome)}
          </p>
        </div>

        {/* 年度总支出 */}
        <div className="bento-item bg-expense-card border-tertiary-soft md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-error">
            <span
              className="w-7 h-7 rounded-full flex items-center justify-center"
              style={{ backgroundColor: 'rgb(167 8 25 / 0.12)' }}
            >
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '16px', color: '#a70819', fontVariationSettings: "'FILL' 1" }}
              >
                trending_up
              </span>
            </span>
            <span className="font-body-md text-body-md font-medium">年度总支出</span>
          </div>
          <p className="font-label-mono text-label-mono text-error text-3xl font-bold">
            -${formatMoney(totalExpense)}
          </p>
        </div>
      </div>

      {/* 柱状图（col-span-8）+ 环形图（col-span-4） */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        {/* 年度收支趋势 */}
        <div className="bento-item bg-bg-card md:col-span-8 min-h-[420px] flex flex-col">
          <div className="flex justify-between items-center mb-6">
            <h3 className="font-headline-md text-headline-md text-text-primary">年度收支趋势</h3>
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-secondary" />
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">收入</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-gray-300" />
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">支出</span>
              </div>
            </div>
          </div>
          <div className="flex-1 flex items-end gap-3 relative">
            {/* Y 轴刻度（左侧） */}
            <div className="absolute left-0 top-0 bottom-6 flex flex-col justify-between text-xs text-on-surface-variant font-caption-sm text-caption-sm pointer-events-none">
              <span>{yAxisMax.toLocaleString('en-US')}</span>
              <span>{Math.round(yAxisMax / 2).toLocaleString('en-US')}</span>
              <span>0</span>
            </div>
            {/* 柱状图区 */}
            <div className="flex-1 ml-10 flex items-end gap-2 h-full pb-6 relative">
              {/* 水平网格线 */}
              <div className="absolute inset-x-0 top-0 border-t border-divider" style={{ top: '0%' }} />
              <div className="absolute inset-x-0 border-t border-divider" style={{ top: '50%' }} />
              <div className="absolute inset-x-0 bottom-6 border-t border-divider" />
              {/* 柱子 */}
              {monthlyData.map((d, i) => {
                const incomeH = yAxisMax > 0 ? (d.income / yAxisMax) * 100 : 0
                const expenseH = yAxisMax > 0 ? (d.expense / yAxisMax) * 100 : 0
                return (
                  <div key={d.month} className="flex-1 flex flex-col items-center gap-1 h-full justify-end relative z-10">
                    <div className="w-full flex flex-col h-full justify-end">
                      {/* 收入柱（绿色，从底部往上叠加支出柱之上） */}
                      <div
                        className="w-full bg-secondary rounded-t-sm transition-all"
                        style={{ height: `${incomeH}%`, minHeight: incomeH > 0 ? '2px' : 0 }}
                        title={`收入 $${formatMoney(d.income)}`}
                      />
                      {/* 支出柱（灰色，紧贴收入柱下方） */}
                      <div
                        className="w-full bg-gray-300 transition-all"
                        style={{ height: `${expenseH}%`, minHeight: expenseH > 0 ? '2px' : 0 }}
                        title={`支出 $${formatMoney(d.expense)}`}
                      />
                    </div>
                    <span className="absolute -bottom-5 font-caption-sm text-caption-sm text-on-surface-variant">
                      {monthLabels[i]}
                    </span>
                  </div>
                )
              })}
            </div>
          </div>
        </div>

        {/* 年度支出构成（环形图 + 分类列表） */}
        <div className="bento-item bg-bg-card md:col-span-4 min-h-[420px] flex flex-col">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">年度支出构成</h3>
          {donutSegments.length === 0 ? (
            <p className="text-on-surface-variant text-center py-12">暂无支出记录</p>
          ) : (
            <>
              <div className="flex-1 relative flex items-center justify-center min-h-[220px]">
                <DonutChart
                  segments={donutSegments}
                  totalValue={`$${(totalExpense / 1000).toFixed(1)}k`}
                />
              </div>
              {/* 分类列表（原型展示前 2 项） */}
              <div className="mt-6 space-y-3 pt-4 border-t border-divider">
                {topCategories.map((cat) => {
                  const color = REPORT_PALETTE[cat.id] ?? '#94a3b8'
                  const pct = totalExpense > 0 ? (cat.total / totalExpense) * 100 : 0
                  return (
                    <div key={cat.id} className="flex items-center gap-3">
                      <span
                        className="w-9 h-9 rounded-full flex items-center justify-center"
                        style={{ backgroundColor: `${color}26` }}
                      >
                        <span
                          className="material-symbols-outlined"
                          style={{ fontSize: '18px', color, fontVariationSettings: "'FILL' 1" }}
                        >
                          {cat.icon}
                        </span>
                      </span>
                      <div className="flex-1">
                        <p className="font-body-md text-body-md text-text-primary font-medium">{cat.name}</p>
                        <p className="font-caption-sm text-caption-sm text-on-surface-variant">
                          {pct.toFixed(0)}%
                        </p>
                      </div>
                      <p className="font-body-md text-body-md text-text-primary font-semibold">
                        ${formatMoney(cat.total)}
                      </p>
                    </div>
                  )
                })}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  )
}