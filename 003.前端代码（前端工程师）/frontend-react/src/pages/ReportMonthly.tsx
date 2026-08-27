import { useMemo } from 'react'
import { Link } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { TRANSACTIONS } from '../data/transactions'
import { EXPENSE_CATEGORIES, INCOME_CATEGORIES } from '../data/categories'
import { LineChart } from '../components/LineChart'
import { DonutChart, type DonutSegment } from '../components/DonutChart'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

// 报表专用配色（与原型一致）
const REPORT_PALETTE: Record<string, string> = {
  housing: '#3b82f6', // 居住 - 蓝
  food: '#f97316', // 餐饮 - 橙
  transport: '#8b5cf6', // 交通 - 紫
  shopping: '#ec4899', // 购物 - 粉
  entertainment: '#06b6d4', // 娱乐 - 青
  medical: '#10b981', // 医疗 - 绿
  education: '#eab308', // 教育 - 黄
  comm: '#94a3b8', // 通讯 - 灰
  salary: '#10b981', // 工资 - 绿
  parttime: '#3b82f6', // 兼职 - 蓝
  investment: '#06b6d4', // 理财 - 青
  redpacket: '#ec4899', // 红包 - 粉
  other: '#94a3b8',
}

const MONTH_OPTIONS = [
  { value: '2026-08', label: '2023年11月', display: 'November 2023' },
]

export function ReportMonthly() {
  usePageTitle('报表')
  usePageBack(null)

  const filterMonth = '2026-08'

  // 当前月交易
  const monthTxns = useMemo(
    () => TRANSACTIONS.filter((t) => t.date.startsWith(filterMonth)),
    [filterMonth],
  )

  // 上一月交易（用于 vs last month 比较）
  const lastMonthTxns = useMemo(() => {
    const [y, m] = filterMonth.split('-')
    const lastMonth = m === '01' ? `${parseInt(y) - 1}-12` : `${y}-${String(parseInt(m) - 1).padStart(2, '0')}`
    return TRANSACTIONS.filter((t) => t.date.startsWith(lastMonth))
  }, [filterMonth])

  const totalIncome = useMemo(
    () => monthTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0),
    [monthTxns],
  )
  const totalExpense = useMemo(
    () => monthTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [monthTxns],
  )
  const netSavings = totalIncome - totalExpense

  const lastMonthNet = useMemo(
    () =>
      lastMonthTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0) -
      lastMonthTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0),
    [lastMonthTxns],
  )
  const netChangePct =
    lastMonthNet !== 0 ? ((netSavings - lastMonthNet) / Math.abs(lastMonthNet)) * 100 : null

  // 收入构成（按分类汇总，原型显示前 2 项）
  const incomeByCategory = useMemo(() => {
    return INCOME_CATEGORIES.map((cat) => ({
      ...cat,
      total: monthTxns
        .filter((t) => t.type === 'income' && t.categoryId === cat.id)
        .reduce((s, t) => s + t.amount, 0),
    }))
      .filter((c) => c.total > 0)
      .sort((a, b) => b.total - a.total)
  }, [monthTxns])

  // 支出构成（按分类汇总，按总额降序）
  const expenseByCategory = useMemo(() => {
    return EXPENSE_CATEGORIES.map((cat) => ({
      ...cat,
      total: monthTxns
        .filter((t) => t.type === 'expense' && t.categoryId === cat.id)
        .reduce((s, t) => s + t.amount, 0),
    }))
      .filter((c) => c.total > 0)
      .sort((a, b) => b.total - a.total)
  }, [monthTxns])

  const topExpenseCategory = expenseByCategory[0]

  // 每日收支数据（30 天）
  const dailyData = useMemo(() => {
    return Array.from({ length: 30 }, (_, i) => {
      const day = String(i + 1).padStart(2, '0')
      const dayTxns = monthTxns.filter((t) => t.date.endsWith(`-${day}`))
      const inc = dayTxns.filter((t) => t.type === 'income').reduce((s, t) => s + t.amount, 0)
      const exp = dayTxns.filter((t) => t.type === 'expense').reduce((s, t) => s + t.amount, 0)
      return { day: i + 1, income: inc, expense: exp }
    })
  }, [monthTxns])

  // 环形图数据：取前 5 大支出分类
  const donutSegments: DonutSegment[] = expenseByCategory.slice(0, 5).map((cat) => ({
    label: cat.name,
    value: cat.total,
    color: REPORT_PALETTE[cat.id] ?? '#94a3b8',
  }))

  // 支出排行：原型展示前 3
  const ranking = expenseByCategory.slice(0, 3)

  const currentMonthDisplay = MONTH_OPTIONS.find((m) => m.value === filterMonth)?.display ?? 'November 2023'

  return (
    <div className="space-y-6">
      {/* 标题 + 日期选择 + 周期切换 */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md text-text-primary leading-none mb-1.5">
            月度统计
          </h2>
          <p className="font-body-md text-body-md text-on-surface-variant">{currentMonthDisplay}</p>
        </div>
        <div className="flex items-center gap-3">
          {/* 月份选择器（白底 + 浅边框） */}
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
            <span className="font-body-md text-body-md font-medium text-text-primary min-w-[88px] text-center">
              2023年11月
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

          {/* 按月/按年 切换（白底容器 + 白卡高亮） */}
          <div className="flex items-center p-1 rounded-xl bg-surface-container border border-transparent">
            <Link
              to="/reports/monthly"
              className={`px-5 py-1.5 font-body-md text-body-md font-medium rounded-lg transition-colors ${
                'bg-bg-card text-primary shadow-sm'
              }`}
            >
              按月
            </Link>
            <Link
              to="/reports/yearly"
              className={`px-5 py-1.5 font-body-md text-body-md font-medium rounded-lg transition-colors text-on-surface-variant hover:text-primary`}
            >
              按年
            </Link>
          </div>
        </div>
      </div>

      {/* 3 个 KPI 卡片（12 列网格，每张占 4 列） */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        {/* 结余 */}
        <div className="bento-item bg-bg-card md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-on-surface-variant">
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '20px', color: '#005394', fontVariationSettings: "'FILL' 1" }}
            >
              account_balance
            </span>
            <span className="font-body-md text-body-md">结余</span>
          </div>
          <p className="font-label-mono text-label-mono text-text-primary text-3xl font-bold">
            ${formatMoney(netSavings)}
          </p>
          <div className="flex items-center gap-2 mt-auto">
            <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-green-50 text-green-700 text-xs font-medium">
              <span className="material-symbols-outlined" style={{ fontSize: '14px', fontVariationSettings: "'FILL' 1" }}>
                trending_up
              </span>
              {netChangePct === null ? '+0.0%' : `${netChangePct >= 0 ? '+' : ''}${netChangePct.toFixed(1)}%`}
            </span>
            <span className="font-caption-sm text-caption-sm text-on-surface-variant">
              vs last month
            </span>
          </div>
        </div>

        {/* 总收入 */}
        <div className="bento-item bg-income-card border-primary-soft md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-primary">
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
            >
              trending_down
            </span>
            <span className="font-body-md text-body-md font-medium">总收入</span>
          </div>
          <p className="font-label-mono text-label-mono text-primary text-3xl font-bold">
            ${formatMoney(totalIncome)}
          </p>
          <div className="mt-auto space-y-1">
            {incomeByCategory.slice(0, 2).map((cat) => (
              <div key={cat.id} className="flex justify-between text-xs">
                <span className="text-on-surface-variant">{cat.name}</span>
                <span className="text-primary font-semibold">${formatMoney(cat.total)}</span>
              </div>
            ))}
            {incomeByCategory.length === 0 && (
              <span className="text-xs text-primary opacity-60">暂无收入</span>
            )}
          </div>
        </div>

        {/* 总支出 */}
        <div className="bento-item bg-expense-card border-tertiary-soft md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-error">
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
            >
              trending_up
            </span>
            <span className="font-body-md text-body-md font-medium">总支出</span>
          </div>
          <p className="font-label-mono text-label-mono text-error text-3xl font-bold">
            ${formatMoney(totalExpense)}
          </p>
          <div className="mt-auto">
            {topExpenseCategory ? (
              <p className="text-xs text-error opacity-80">
                Top category: {topExpenseCategory.name} (${formatMoney(topExpenseCategory.total)})
              </p>
            ) : (
              <span className="text-xs text-error opacity-60">暂无支出</span>
            )}
          </div>
        </div>
      </div>

      {/* 折线图（col-span-8）+ 环形图（col-span-4） */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        {/* 每日收支趋势 */}
        <div className="bento-item bg-bg-card md:col-span-8 min-h-[300px] flex flex-col">
          <div className="flex justify-between items-center mb-4">
            <h3 className="font-headline-md text-headline-md text-text-primary">每日收支趋势</h3>
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-primary" />
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                  收入
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-error" />
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                  支出
                </span>
              </div>
            </div>
          </div>
          <LineChart data={dailyData} />
        </div>

        {/* 支出占比（col-span-4，居中展示环形图） */}
        <div className="bento-item bg-bg-card md:col-span-4 min-h-[300px] flex flex-col">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-6">支出占比</h3>
          {donutSegments.length === 0 ? (
            <p className="text-on-surface-variant text-center py-12">暂无支出记录</p>
          ) : (
            <div className="flex-1 relative flex items-center justify-center">
              <DonutChart
                segments={donutSegments}
                totalValue={`$${Math.round(totalExpense).toLocaleString('en-US')}`}
              />
            </div>
          )}
        </div>
      </div>

      {/* 支出排行（无卡片包裹） */}
      <div>
        <h3 className="font-headline-md text-headline-md text-text-primary mb-4">支出排行</h3>
        {ranking.length === 0 ? (
          <p className="text-on-surface-variant text-center py-8">暂无支出记录</p>
        ) : (
          <div className="space-y-5">
            {ranking.map((cat) => {
              const color = REPORT_PALETTE[cat.id] ?? '#94a3b8'
              const pct = totalExpense > 0 ? (cat.total / totalExpense) * 100 : 0
              return (
                <div key={cat.id}>
                  <div className="flex justify-between items-center mb-2">
                    <div className="flex items-center gap-2">
                      <span
                        className="w-8 h-8 rounded-full flex items-center justify-center"
                        style={{ backgroundColor: `${color}26` }}
                      >
                        <span
                          className="material-symbols-outlined"
                          style={{ fontSize: '16px', color, fontVariationSettings: "'FILL' 1" }}
                        >
                          {cat.icon}
                        </span>
                      </span>
                      <span className="font-body-md text-body-md text-text-primary font-medium">
                        {cat.name}
                      </span>
                    </div>
                    <div className="text-right">
                      <p className="font-body-md text-body-md text-text-primary font-semibold">
                        ${formatMoney(cat.total)}
                      </p>
                      <p className="font-caption-sm text-caption-sm text-on-surface-variant">
                        {pct.toFixed(0)}%
                      </p>
                    </div>
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
        )}
      </div>
    </div>
  )
}