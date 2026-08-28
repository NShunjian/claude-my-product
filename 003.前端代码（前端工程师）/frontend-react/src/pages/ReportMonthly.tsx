import { useMemo, useState } from 'react'
import { Link } from 'react-router-dom'
import { usePageTitle, usePageBack } from '../components/PageTitleContext'
import { LineChart } from '../components/LineChart'
import { DonutChart, type DonutSegment } from '../components/DonutChart'
import { MonthPicker } from '../components/MonthPicker'
import { useMonthlyReport } from '../lib/hooks'
import { getCategoryPresentationById } from '../lib/category-presentation'
import { useLanguage } from '../i18n/LanguageContext'
import type { CategoryTotal, DailyPoint, MonthlyReport } from '../api/reports'

function formatMoney(amount: number): string {
  return new Intl.NumberFormat('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(amount)
}

function formatMonth(month: string, t: (key: string) => string): string {
  const [y, m] = month.split('-')
  return t('reportMonthly.monthYear')
    .replace('{y}', y)
    .replace('{m}', String(parseInt(m, 10)))
}

function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split('-').map(Number)
  const d = new Date(y, m - 1 + delta, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

function currentMonth(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

/** 把后端 DailyPoint 数组补齐到当前月天数（短月补 0） */
function fillDailyData(report: MonthlyReport): DailyPoint[] {
  const [y, m] = report.month.split('-').map(Number)
  const daysInMonth = new Date(y, m, 0).getDate()
  const byDay = new Map(report.dailyData.map((d) => [d.day, d]))
  return Array.from({ length: daysInMonth }, (_, i) => {
    const day = i + 1
    return byDay.get(day) ?? { day, income: 0, expense: 0 }
  })
}

export function ReportMonthly() {
  const { t } = useLanguage()
  usePageTitle(t('pageTitle.reportMonthly'))
  usePageBack(null)

  const [filterMonth, setFilterMonth] = useState<string>(currentMonth())
  const reportQ = useMonthlyReport(filterMonth)
  const report = reportQ.data

  // 可选年份范围(覆盖种子数据起始年 2021 + 当前年后 2 年留余量)
  const yearOptions = useMemo(() => {
    const cur = new Date().getFullYear()
    const years: number[] = []
    for (let y = 2020; y <= cur + 2; y++) years.push(y)
    return years
  }, [])

  const dailyData = useMemo(() => (report ? fillDailyData(report) : []), [report])

  const totalIncome = report?.totalIncome ?? 0
  const totalExpense = report?.totalExpense ?? 0
  const netSavings = report?.netSavings ?? 0

  const lastMonth = report?.lastMonth ?? null
  const netChangePct =
    lastMonth && lastMonth.netSavings !== 0
      ? ((netSavings - lastMonth.netSavings) / Math.abs(lastMonth.netSavings)) * 100
      : null

  // 收入排行（按总额降序）
  const incomeRanking = useMemo(() => {
    if (!report) return []
    return report.incomeByCategory
      .slice()
      .sort((a, b) => b.total - a.total)
      .slice(0, 3)
  }, [report])

  const expenseRanking = useMemo(() => {
    if (!report) return []
    return report.expenseByCategory
      .slice()
      .sort((a, b) => b.total - a.total)
      .slice(0, 3)
  }, [report])

  const topExpense = expenseRanking[0]

  // 环形图（支出前 5）
  const expenseDonutSegments = useMemo<DonutSegment[]>(() => {
    return expenseRanking.slice(0, 5).map((cat) => ({
      label: cat.name,
      value: cat.total,
      color: getCategoryPresentationById(cat.categoryId).colorHex,
    }))
  }, [expenseRanking])

  const incomeDonutSegments = useMemo<DonutSegment[]>(() => {
    return incomeRanking.map((cat) => ({
      label: cat.name,
      value: cat.total,
      color: getCategoryPresentationById(cat.categoryId).colorHex,
    }))
  }, [incomeRanking])

  function goPrev() { setFilterMonth((m) => shiftMonth(m, -1)) }
  function goNext() { setFilterMonth((m) => shiftMonth(m, 1)) }

  const isLoading = reportQ.loading
  const isError = !isLoading && !!reportQ.error
  const errMsg = reportQ.error?.message ?? null

  function renderCategoryRow(cat: CategoryTotal, total: number) {
    const pres = getCategoryPresentationById(cat.categoryId)
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
            <span className="font-body-md text-body-md text-text-primary font-medium">
              {cat.name}
            </span>
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
      {/* 标题 + 日期选择 + 周期切换 */}
      <div className="flex flex-wrap items-center justify-between gap-4">
        <div>
          <h2 className="font-headline-md text-headline-md text-text-primary leading-none mb-1.5">
            {t('reportMonthly.title')}
          </h2>
          <p className="font-body-md text-body-md text-on-surface-variant">
            {formatMonth(filterMonth, t)}
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 px-4 py-2 rounded-xl bg-bg-card border border-divider">
            <button
              type="button"
              onClick={goPrev}
              aria-label={t('reportMonthly.prevMonth')}
              className="text-on-surface-variant hover:text-primary transition-colors"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
                chevron_left
              </span>
            </button>
            <MonthPicker
              value={filterMonth}
              onChange={setFilterMonth}
              yearOptions={yearOptions}
              displayTemplate={t('reportMonthly.monthYear')}
              triggerLabel={t('reportMonthly.pickMonth')}
              labels={{
                yearLabel: t('reportMonthly.picker.yearLabel'),
                clear: t('reportMonthly.picker.clear'),
                thisMonth: t('reportMonthly.picker.thisMonth'),
              }}
            />
            <button
              type="button"
              onClick={goNext}
              aria-label={t('reportMonthly.nextMonth')}
              className="text-on-surface-variant hover:text-primary transition-colors"
            >
              <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>
                chevron_right
              </span>
            </button>
          </div>

          <div className="flex items-center p-1 rounded-xl bg-surface-container border border-transparent">
            <Link
              to="/reports/monthly"
              className="px-5 py-1.5 font-body-md text-body-md font-medium rounded-lg transition-colors bg-bg-card text-primary shadow-sm"
            >
              {t('reportMonthly.tabMonthly')}
            </Link>
            <Link
              to="/reports/yearly"
              className="px-5 py-1.5 font-body-md text-body-md font-medium rounded-lg transition-colors text-on-surface-variant hover:text-primary"
            >
              {t('reportMonthly.tabYearly')}
            </Link>
          </div>
        </div>
      </div>

      {isError && (
        <div className="bg-error-container text-on-error-container rounded-xl p-4 font-body-md text-body-md">
          {t('reportMonthly.loadErrorPrefix')}{errMsg}
        </div>
      )}

      {/* 3 个 KPI 卡片 */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        <div className="bento-item bg-bg-card md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-on-surface-variant">
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '20px', color: '#005394', fontVariationSettings: "'FILL' 1" }}
            >
              account_balance
            </span>
            <span className="font-body-md text-body-md">{t('reportMonthly.netSavings')}</span>
          </div>
          <p className="font-label-mono text-label-mono text-text-primary text-3xl font-bold">
            ¥{formatMoney(netSavings)}
          </p>
          <div className="flex items-center gap-2 mt-auto">
            <span className={`inline-flex items-center gap-1 px-2 py-1 rounded-full text-xs font-medium ${
              (netChangePct ?? 0) >= 0 ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700'
            }`}>
              <span className="material-symbols-outlined" style={{ fontSize: '14px', fontVariationSettings: "'FILL' 1" }}>
                {(netChangePct ?? 0) >= 0 ? 'trending_up' : 'trending_down'}
              </span>
              {netChangePct === null ? '+0.0%' : `${netChangePct >= 0 ? '+' : ''}${netChangePct.toFixed(1)}%`}
            </span>
            <span className="font-caption-sm text-caption-sm text-on-surface-variant">
              {t('reportMonthly.lastMonth')}
            </span>
          </div>
        </div>

        <div className="bento-item bg-income-card border-primary-soft md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-primary">
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
            >
              trending_down
            </span>
            <span className="font-body-md text-body-md font-medium">{t('reportMonthly.totalIncomeLabel')}</span>
          </div>
          <p className="font-label-mono text-label-mono text-primary text-3xl font-bold">
            ¥{formatMoney(totalIncome)}
          </p>
          <div className="mt-auto space-y-1">
            {incomeRanking.slice(0, 2).map((cat) => (
              <div key={cat.categoryId} className="flex justify-between text-xs">
                <span className="text-on-surface-variant">{cat.name}</span>
                <span className="text-primary font-semibold">¥{formatMoney(cat.total)}</span>
              </div>
            ))}
            {incomeRanking.length === 0 && (
              <span className="text-xs text-primary opacity-60">{t('reportMonthly.noIncome')}</span>
            )}
          </div>
        </div>

        <div className="bento-item bg-expense-card border-tertiary-soft md:col-span-4 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-error">
            <span
              className="material-symbols-outlined"
              style={{ fontSize: '20px', fontVariationSettings: "'FILL' 1" }}
            >
              trending_up
            </span>
            <span className="font-body-md text-body-md font-medium">{t('reportMonthly.totalExpenseLabel')}</span>
          </div>
          <p className="font-label-mono text-label-mono text-error text-3xl font-bold">
            ¥{formatMoney(totalExpense)}
          </p>
          <div className="mt-auto">
            {topExpense ? (
              <p className="text-xs text-error opacity-80">
                {t('reportMonthly.topCategoryPrefix')}{topExpense.name}（¥{formatMoney(topExpense.total)}）
              </p>
            ) : (
              <span className="text-xs text-error opacity-60">{t('reportMonthly.noExpense')}</span>
            )}
          </div>
        </div>
      </div>

      {/* 折线图（col-8）+ 支出占比（col-4） */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        <div className="bento-item bg-bg-card md:col-span-8 min-h-[300px] flex flex-col">
          <div className="flex justify-between items-center mb-4">
            <h3 className="font-headline-md text-headline-md text-text-primary">{t('reportMonthly.dailyTrend')}</h3>
            <div className="flex items-center gap-4" style={{ paddingRight: '2.5%' }}>
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-primary" />
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                  {t('chart.line.income')}
                </span>
              </div>
              <div className="flex items-center gap-1.5">
                <span className="w-2.5 h-2.5 rounded-full bg-error" />
                <span className="font-caption-sm text-caption-sm text-on-surface-variant">
                  {t('chart.line.expense')}
                </span>
              </div>
            </div>
          </div>
          {isLoading ? (
            <p className="text-on-surface-variant font-body-md text-body-md text-center py-12">{t('common.loading')}</p>
          ) : (
            <LineChart data={dailyData} />
          )}
        </div>

        {/* 支出占比（与下方支出配对的同一份数据，复用） */}
        <div className="bento-item bg-bg-card md:col-span-4 min-h-[300px] flex flex-col">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-6">{t('reportMonthly.expenseShare')}</h3>
          {expenseDonutSegments.length === 0 ? (
            <p className="text-on-surface-variant text-center py-12">{t('reportMonthly.noExpenseRecords')}</p>
          ) : (
            <div className="flex-1 relative flex items-center justify-center">
              <DonutChart
                segments={expenseDonutSegments}
                totalValue={`¥${Math.round(totalExpense).toLocaleString('zh-CN')}`}
              />
            </div>
          )}
        </div>
      </div>

      {/* 收入占比 + 收入排行 */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        <div className="bento-item bg-bg-card md:col-span-4 min-h-[300px] flex flex-col">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-6">{t('reportMonthly.incomeShare')}</h3>
          {incomeDonutSegments.length === 0 ? (
            <p className="text-on-surface-variant text-center py-12">{t('reportMonthly.noIncomeRecords')}</p>
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
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">{t('reportMonthly.incomeRanking')}</h3>
          {incomeRanking.length === 0 ? (
            <p className="text-on-surface-variant text-center py-8">{t('reportMonthly.noIncomeRecords')}</p>
          ) : (
            <div className="space-y-5 flex-1">
              {incomeRanking.map((cat) => renderCategoryRow(cat, totalIncome))}
            </div>
          )}
        </div>
      </div>

      {/* 支出占比 + 支出排行（与收入配对布局一致） */}
      <div className="grid grid-cols-1 md:grid-cols-12 gap-6">
        <div className="bento-item bg-bg-card md:col-span-4 min-h-[300px] flex flex-col">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-6">{t('reportMonthly.expenseShare')}</h3>
          {expenseDonutSegments.length === 0 ? (
            <p className="text-on-surface-variant text-center py-12">{t('reportMonthly.noExpenseRecords')}</p>
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
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">{t('reportMonthly.expenseRanking')}</h3>
          {expenseRanking.length === 0 ? (
            <p className="text-on-surface-variant text-center py-8">{t('reportMonthly.noExpenseRecords')}</p>
          ) : (
            <div className="space-y-5 flex-1">
              {expenseRanking.map((cat) => renderCategoryRow(cat, totalExpense))}
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
