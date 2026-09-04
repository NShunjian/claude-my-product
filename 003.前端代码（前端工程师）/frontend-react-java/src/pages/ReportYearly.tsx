import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { DonutChart, type DonutSegment } from '../components/DonutChart'
import { useYearlyReport } from '../lib/hooks'
import { getCategoryPresentationByTotal } from '../lib/category-presentation'
import { useLanguage } from '../i18n/LanguageContext'
import type { CategoryTotal, MonthlyPoint, YearlyReport } from '../api/reports'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(Math.abs(amount))
}

/** 把后端 MonthlyPoint 数组补齐到 12 个月 */
function fillMonthlyData(report: YearlyReport): MonthlyPoint[] {
  const byMonth = new Map(report.monthlyData.map((d) => [d.month, d]))
  return Array.from({ length: 12 }, (_, i) => {
    const month = i + 1
    return byMonth.get(month) ?? { month, income: 0, expense: 0 }
  })
}

function currentYear(): number {
  return new Date().getFullYear()
}

export function ReportYearly() {
  const { t } = useLanguage()
  usePageTitle(t('pageTitle.reportYearly'))
  usePageBack(null)

  const [filterYear, setFilterYear] = useState<number>(currentYear())
  const reportQ = useYearlyReport(filterYear)
  const report = reportQ.data

  // 可选年份范围:覆盖种子数据起始年(2021)到当前年之后 2 年
  const yearOptions = useMemo(() => {
    const cur = currentYear()
    const years: number[] = []
    for (let y = 2020; y <= cur + 2; y++) years.push(y)
    return years
  }, [])

  const monthlyData = useMemo(() => (report ? fillMonthlyData(report) : []), [report])

  const totalIncome = report?.totalIncome ?? 0
  const totalExpense = report?.totalExpense ?? 0
  const netSavings = report?.netSavings ?? 0

  const yAxisMax = useMemo(() => {
    const raw = Math.max(...monthlyData.map((d) => Math.max(d.income, d.expense)), 0)
    return Math.ceil(raw / 5000) * 5000 || 10000
  }, [monthlyData])

  const expenseByCategory = useMemo(() => {
    if (!report) return []
    return (report.expenseByCategory ?? []).slice().sort((a, b) => b.total - a.total)
  }, [report])

  const incomeByCategory = useMemo(() => {
    if (!report) return []
    return (report.incomeByCategory ?? []).slice().sort((a, b) => b.total - a.total)
  }, [report])

  const expenseDonutSegments: DonutSegment[] = useMemo(() => {
    return expenseByCategory.map((cat) => ({
      label: cat.name,
      value: cat.total,
      color: getCategoryPresentationByTotal(cat).colorHex,
    }))
  }, [expenseByCategory])

  const incomeDonutSegments: DonutSegment[] = useMemo(() => {
    return incomeByCategory.map((cat) => ({
      label: cat.name,
      value: cat.total,
      color: getCategoryPresentationByTotal(cat).colorHex,
    }))
  }, [incomeByCategory])

  const monthKeys = useMemo(
    () => [
      'reportYearly.monthJan',
      'reportYearly.monthFeb',
      'reportYearly.monthMar',
      'reportYearly.monthApr',
      'reportYearly.monthMay',
      'reportYearly.monthJun',
      'reportYearly.monthJul',
      'reportYearly.monthAug',
      'reportYearly.monthSep',
      'reportYearly.monthOct',
      'reportYearly.monthNov',
      'reportYearly.monthDec',
    ],
    [],
  )
  const monthLabels = monthKeys.map((k) => t(k))

  const isLoading = reportQ.loading
  const isError = !isLoading && !!reportQ.error
  const errMsg = reportQ.error?.message ?? null

  function renderCategoryRow(cat: CategoryTotal, total: number) {
    const pres = getCategoryPresentationByTotal(cat)
    const pct = total > 0 ? (cat.total / total) * 100 : 0
    return (
      <div key={cat.categoryId}>
        <div className="flex justify-between items-center mb-2">
          <div className="flex items-center gap-2">
            <span
              className="w-8 h-8 rounded-full flex items-center justify-center"
              style={{ backgroundColor: `${pres.colorHex}26` }}
            >
              <span
                className="material-symbols-outlined"
                style={{ fontSize: '16px', color: pres.colorHex, fontVariationSettings: "'FILL' 1" }}
              >
                {pres.icon}
              </span>
            </span>
            <span className="font-body-md text-body-md text-text-primary font-medium">{cat.name}</span>
          </div>
          <div className="text-right">
            <p className="font-body-md text-body-md text-text-primary font-semibold">
              ¥{formatMoney(cat.total)}
            </p>
            <p className="font-caption-sm text-caption-sm text-on-surface-variant">
              {pct.toFixed(0)}%
            </p>
          </div>
        </div>
        <div className="h-2 bg-surface-container rounded-full overflow-hidden">
          <div
            className="h-full rounded-full transition-all"
            style={{ width: `${pct}%`, backgroundColor: pres.colorHex }}
          />
        </div>
      </div>
    )
  }

  return (
    <div className="space-y-6">
      {/* 标题 + 年份选择 + 月报/年报 切换 */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md text-text-primary leading-none mb-1.5">
            {t('reportYearly.title')}
          </h2>
          <p className="font-body-md text-body-md text-on-surface-variant">{t('reportYearly.yearOnly').replace('{y}', String(filterYear))}</p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-4 py-2 rounded-xl bg-bg-card border border-divider">
            <button
              type="button"
              onClick={() => setFilterYear((y) => y - 1)}
              aria-label={t('reportYearly.prevYear')}
              disabled={!yearOptions.includes(filterYear - 1)}
              className="text-on-surface-variant hover:text-primary transition-colors disabled:opacity-40 disabled:hover:text-on-surface-variant disabled:cursor-not-allowed"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
                chevron_left
              </span>
            </button>
            <div className="relative flex items-center gap-2">
              <span
                className="material-symbols-outlined text-primary pointer-events-none"
                style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
              >
                calendar_month
              </span>
              <select
                value={filterYear}
                onChange={(e) => setFilterYear(parseInt(e.target.value, 10))}
                aria-label={t('reportYearly.pickYear')}
                className="appearance-none bg-transparent font-body-md text-body-md font-medium text-text-primary pr-6 cursor-pointer focus:outline-none"
              >
                {yearOptions.map((y) => (
                  <option key={y} value={y}>
                    {t('reportYearly.yearOnly').replace('{y}', String(y))}
                  </option>
                ))}
              </select>
              <span
                className="material-symbols-outlined absolute right-0 top-1/2 -translate-y-1/2 pointer-events-none text-on-surface-variant"
                style={{ fontSize: '18px' }}
              >
                expand_more
              </span>
            </div>
            <button
              type="button"
              onClick={() => setFilterYear((y) => y + 1)}
              aria-label={t('reportYearly.nextYear')}
              disabled={!yearOptions.includes(filterYear + 1)}
              className="text-on-surface-variant hover:text-primary transition-colors disabled:opacity-40 disabled:hover:text-on-surface-variant disabled:cursor-not-allowed"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
                chevron_right
              </span>
            </button>
          </div>

          <div className="flex items-center p-1 rounded-xl bg-surface-container border border-transparent">
            <Link
              to="/reports/monthly"
              className="px-5 py-1.5 font-body-md text-body-md font-medium rounded-lg transition-colors text-on-surface-variant hover:text-primary"
            >
              {t('reportYearly.tabMonthly')}
            </Link>
            <Link
              to="/reports/yearly"
              className="px-5 py-1.5 font-body-md text-body-md font-medium rounded-lg transition-colors bg-bg-card text-primary shadow-sm"
            >
              {t('reportYearly.tabYearly')}
            </Link>
          </div>
        </div>
      </div>

      {isError && (
        <div className="bg-error-container text-on-error-container rounded-xl p-4 font-body-md text-body-md">
          {t('reportYearly.loadErrorPrefix')}{errMsg}
        </div>
      )}

      {/* 3 个 KPI 卡片 */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
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
            <span className="font-body-md text-body-md">{t('reportYearly.netSavingsLabel')}</span>
          </div>
          <p
            className={`font-label-mono text-label-mono text-3xl font-bold ${
              netSavings >= 0 ? 'text-primary' : 'text-error'
            }`}
          >
            {netSavings >= 0 ? '' : '-'}{`¥${formatMoney(netSavings)}`}
          </p>
        </div>

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
            <span className="font-body-md text-body-md font-medium">{t('reportYearly.totalIncomeLabel')}</span>
          </div>
          <p className="font-label-mono text-label-mono text-primary text-3xl font-bold">
            ¥{formatMoney(totalIncome)}
          </p>
        </div>

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
            <span className="font-body-md text-body-md font-medium">{t('reportYearly.totalExpenseLabel')}</span>
          </div>
          <p className="font-label-mono text-label-mono text-error text-3xl font-bold">
            ¥{formatMoney(totalExpense)}
          </p>
        </div>
      </div>

      {/* 柱状图 + 环形图(年报布局:柱状图全宽,环形图+分类进度条放在底下) */}
      <div className="space-y-6">
        {/* 柱状图(全宽) */}
        <div className="bento-item bg-bg-card min-h-[420px] flex flex-col">
          <div className="flex justify-between items-center mb-6">
            <h3 className="font-headline-md text-headline-md text-text-primary">{t('reportYearly.monthlyTrend')}</h3>
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-secondary" />
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">{t('chart.line.income')}</span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-error" />
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">{t('chart.line.expense')}</span>
              </div>
            </div>
          </div>
          {isLoading ? (
            <p className="text-on-surface-variant font-body-md text-body-md text-center py-12">{t('common.loading')}</p>
          ) : (
            <div className="flex-1 flex items-end gap-3 relative">
              <div className="absolute left-0 top-0 bottom-6 flex flex-col justify-between text-xs text-on-surface-variant font-caption-sm text-caption-sm pointer-events-none">
                <span>{yAxisMax.toLocaleString('zh-CN')}</span>
                <span>{Math.round(yAxisMax / 2).toLocaleString('zh-CN')}</span>
                <span>0</span>
              </div>
              <div className="flex-1 ml-10 flex gap-2 relative pb-6 h-[260px]">
                <div className="absolute inset-x-0 top-0 border-t border-divider" />
                <div className="absolute inset-x-0 border-t border-divider" style={{ top: '50%' }} />
                <div className="absolute inset-x-0 bottom-6 border-t border-divider" />
                {monthlyData.map((d, i) => {
                  const incomeH = yAxisMax > 0 ? (d.income / yAxisMax) * 200 : 0
                  const expenseH = yAxisMax > 0 ? (d.expense / yAxisMax) * 200 : 0
                  return (
                    <div key={d.month} className="flex-1 h-full flex flex-col items-center justify-end relative">
                      <div className="w-full flex gap-0.5 items-end h-[200px]">
                        <div
                          className="flex-1 bg-secondary rounded-t-sm transition-all"
                          style={{ height: `${incomeH}px`, minHeight: incomeH > 0 ? '2px' : 0 }}
                          title={t('reportYearly.incomeTip').replace('{amount}', formatMoney(d.income))}
                        />
                        <div
                          className="flex-1 bg-error transition-all"
                          style={{ height: `${expenseH}px`, minHeight: expenseH > 0 ? '2px' : 0 }}
                          title={t('reportYearly.expenseTip').replace('{amount}', formatMoney(d.expense))}
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
          )}
        </div>

        {/* 收入占比 + 收入排行(参考月报布局:环形图 + 排行进度条 side-by-side) */}
        <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
          <div className="bento-item bg-bg-card md:col-span-4 h-[420px] flex flex-col">
            <h3 className="font-headline-md text-headline-md text-text-primary mb-6">{t('reportYearly.incomeShare')}</h3>
            {incomeDonutSegments.length === 0 ? (
              <p className="text-on-surface-variant text-center py-12">{t('reportYearly.noIncomeRecords')}</p>
            ) : (
              <div className="flex-1 relative flex items-center justify-center">
                <DonutChart
                  segments={incomeDonutSegments}
                  totalValue={`¥${Math.round(totalIncome).toLocaleString('zh-CN')}`}
                />
              </div>
            )}
          </div>

          <div className="bento-item bg-bg-card md:col-span-8 p-6 flex flex-col">
            <h3 className="font-headline-md text-headline-md text-text-primary mb-4">{t('reportYearly.incomeRanking')}</h3>
            {incomeByCategory.length === 0 ? (
              <p className="text-on-surface-variant text-center py-8">{t('reportYearly.noIncomeRecords')}</p>
            ) : (
              <div className="space-y-5 flex-1">
                {incomeByCategory.map((cat) => renderCategoryRow(cat, totalIncome))}
              </div>
            )}
          </div>
        </div>

        {/* 支出占比 + 支出排行(与收入配对布局一致) */}
        <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
          <div className="bento-item bg-bg-card md:col-span-4 h-[420px] flex flex-col">
            <h3 className="font-headline-md text-headline-md text-text-primary mb-6">{t('reportYearly.expenseShare')}</h3>
            {expenseDonutSegments.length === 0 ? (
              <p className="text-on-surface-variant text-center py-12">{t('reportYearly.noExpenseRecords')}</p>
            ) : (
              <div className="flex-1 relative flex items-center justify-center">
                <DonutChart
                  segments={expenseDonutSegments}
                  totalValue={`¥${Math.round(totalExpense).toLocaleString('zh-CN')}`}
                />
              </div>
            )}
          </div>

          <div className="bento-item bg-bg-card md:col-span-8 p-6 flex flex-col">
            <h3 className="font-headline-md text-headline-md text-text-primary mb-4">{t('reportYearly.expenseRanking')}</h3>
            {expenseByCategory.length === 0 ? (
              <p className="text-on-surface-variant text-center py-8">{t('reportYearly.noExpenseRecords')}</p>
            ) : (
              <div className="space-y-5 flex-1">
                {expenseByCategory.map((cat) => renderCategoryRow(cat, totalExpense))}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
