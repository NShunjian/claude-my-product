<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useBookStore } from '@/stores/book'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { getMonthlyReport, getYearlyReport } from '@/api/reports'
import { categoryPresentation } from '@/utils/category-presentation'
import { formatAmount } from '@/utils/finance'
import MonthPicker from '@/components/MonthPicker.vue'
import LineChart from '@/components/charts/LineChart.vue'
import DonutChart from '@/components/DonutChart.vue'
import type { MonthlyReport, DailyPoint, YearlyReport, MonthlyPoint } from '@/api/reports'

const book = useBookStore()
const auth = useAuthStore()
const toast = useToastStore()
const { t } = useLanguage()

type ViewMode = 'monthly' | 'yearly'
const mode = ref<ViewMode>('monthly')

function currentMonth(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}
function currentYear(): number {
  return new Date().getFullYear()
}

function fillDailyData(report: MonthlyReport): DailyPoint[] {
  const [y, m] = report.month.split('-').map(Number)
  const daysInMonth = new Date(y, m, 0).getDate()
  const byDay = new Map(report.dailyData.map((d) => [d.day, d]))
  return Array.from({ length: daysInMonth }, (_, i) => {
    const day = i + 1
    return byDay.get(day) ?? { day, income: 0, expense: 0 }
  })
}

function fillMonthlyData(report: YearlyReport): MonthlyPoint[] {
  const byMonth = new Map(report.monthlyData.map((d) => [d.month, d]))
  return Array.from({ length: 12 }, (_, i) => {
    const month = i + 1
    return byMonth.get(month) ?? { month, income: 0, expense: 0 }
  })
}

// === Monthly state ===
const filterMonth = ref(currentMonth())
const monthlyReport = ref<MonthlyReport | null>(null)
const monthlyLoading = ref(false)
const monthlyError = ref<string | null>(null)

const dailyData = computed(() => monthlyReport.value ? fillDailyData(monthlyReport.value) : [])
const monthlyTotalIncome = computed(() => monthlyReport.value?.totalIncome ?? 0)
const monthlyTotalExpense = computed(() => monthlyReport.value?.totalExpense ?? 0)
const monthlyNetSavings = computed(() => monthlyReport.value?.netSavings ?? 0)
const lastMonth = computed(() => monthlyReport.value?.lastMonth ?? null)
const monthlyNetChangePct = computed(() => {
  if (!lastMonth.value || lastMonth.value.netSavings === 0) return null
  return ((monthlyNetSavings.value - lastMonth.value.netSavings) / Math.abs(lastMonth.value.netSavings)) * 100
})

const incomeRanking = computed(() => {
  if (!monthlyReport.value) return []
  return [...monthlyReport.value.incomeByCategory].sort((a, b) => b.total - a.total)
    .map((c) => ({ ...c, pres: categoryPresentation({ id: c.categoryId, type: 'income', name: c.name }) }))
})
const expenseRanking = computed(() => {
  if (!monthlyReport.value) return []
  return [...monthlyReport.value.expenseByCategory].sort((a, b) => b.total - a.total)
    .map((c) => ({ ...c, pres: categoryPresentation({ id: c.categoryId, type: 'expense', name: c.name }) }))
})
const topExpense = computed(() => expenseRanking.value[0] ?? null)
const incomeDonutSegments = computed(() =>
  incomeRanking.value.map((cat) => ({
    label: cat.name,
    value: cat.total,
    color: categoryPresentation({ id: cat.categoryId, type: 'income', name: cat.name }).color,
  }))
)
const expenseDonutSegments = computed(() =>
  expenseRanking.value.map((cat) => ({
    label: cat.name,
    value: cat.total,
    color: categoryPresentation({ id: cat.categoryId, type: 'expense', name: cat.name }).color,
  }))
)

// === Yearly state ===
const filterYear = ref(currentYear())
const yearlyReport = ref<YearlyReport | null>(null)
const yearlyLoading = ref(false)
const yearlyError = ref<string | null>(null)

const yearlyMonthlyData = computed(() => yearlyReport.value ? fillMonthlyData(yearlyReport.value) : [])
const yearlyTotalIncome = computed(() => yearlyReport.value?.totalIncome ?? 0)
const yearlyTotalExpense = computed(() => yearlyReport.value?.totalExpense ?? 0)
const yearlyNetSavings = computed(() => yearlyReport.value?.netSavings ?? 0)
const yearlyExpenseByCategory = computed(() => {
  if (!yearlyReport.value) return []
  return [...yearlyReport.value.expenseByCategory].sort((a, b) => b.total - a.total)
    .map((c) => ({ ...c, pres: categoryPresentation({ id: c.categoryId, type: 'expense', name: c.name }) }))
})
const yearlyDonutSegments = computed(() =>
  yearlyExpenseByCategory.value.map((cat) => ({
    label: cat.name,
    value: cat.total,
    color: cat.pres.color,
  }))
)
const monthLabels = computed(() => [
  t('reportYearly.monthJan'), t('reportYearly.monthFeb'), t('reportYearly.monthMar'),
  t('reportYearly.monthApr'), t('reportYearly.monthMay'), t('reportYearly.monthJun'),
  t('reportYearly.monthJul'), t('reportYearly.monthAug'), t('reportYearly.monthSep'),
  t('reportYearly.monthOct'), t('reportYearly.monthNov'), t('reportYearly.monthDec'),
])
const yAxisMax = computed(() => {
  const raw = Math.max(...yearlyMonthlyData.value.map((d) => Math.max(d.income, d.expense)), 0)
  return Math.ceil(raw / 5000) * 5000 || 10000
})

async function loadMonthly() {
  if (!auth.token || !book.current) return
  monthlyLoading.value = true
  monthlyError.value = null
  try {
    monthlyReport.value = await getMonthlyReport(filterMonth.value, book.current.uuid)
  } catch (e: any) {
    monthlyError.value = e?.message ?? '加载失败'
  } finally {
    monthlyLoading.value = false
  }
}

async function loadYearly() {
  if (!auth.token || !book.current) return
  yearlyLoading.value = true
  yearlyError.value = null
  try {
    yearlyReport.value = await getYearlyReport(filterYear.value, book.current.uuid)
  } catch (e: any) {
    yearlyError.value = e?.message ?? '加载失败'
  } finally {
    yearlyLoading.value = false
  }
}

function syncYearly() {
  if (mode.value === 'yearly') loadYearly()
}
function syncMonthly() {
  if (mode.value === 'monthly') loadMonthly()
}

watch([filterMonth, () => book.current], syncMonthly, { immediate: true })
watch([filterYear, () => book.current], syncYearly, { immediate: true })
watch(mode, () => {
  if (mode.value === 'monthly') loadMonthly()
  else loadYearly()
})
onShow(() => {
  if (mode.value === 'monthly') loadMonthly()
  else loadYearly()
})

const yearOptions = computed(() =>
  Array.from({ length: 10 }, (_, i) => new Date().getFullYear() - 5 + i)
)
function pickYear(e: any) {
  filterYear.value = yearOptions.value[Number(e.detail.value)]
}
</script>

<template>
  <view class="page">
    <!-- === Monthly view === -->
    <template v-if="mode === 'monthly'">
      <view class="header-row">
        <view class="title-block">
          <text class="page-title">{{ t('reportMonthly.title') }}</text>
          <text class="page-subtitle">{{ filterMonth.slice(0, 4) }} 年 {{ Number(filterMonth.slice(5)) }} 月</text>
        </view>
        <view class="month-ctrl">
          <MonthPicker v-model="filterMonth" />
        </view>
      </view>

      <view class="tab-bar">
        <view class="tab active">{{ t('reportMonthly.tabMonthly') }}</view>
        <view class="tab" @tap="mode = 'yearly'">{{ t('reportMonthly.tabYearly') }}</view>
      </view>

      <view v-if="monthlyError" class="error-box">{{ t('reportMonthly.loadErrorPrefix') }}{{ monthlyError }}</view>

      <view class="kpi-list">
        <view class="kpi-card kpi-net">
          <view class="kpi-head">
            <view class="kpi-icon-wrap kpi-icon-blue">
              <text class="kpi-icon">account_balance</text>
            </view>
            <text class="kpi-label">{{ t('reportMonthly.netSavings') }}</text>
          </view>
          <text class="kpi-amount" :class="monthlyNetSavings >= 0 ? 'income' : 'expense'">
            {{ monthlyNetSavings >= 0 ? '' : '-' }}¥ {{ formatAmount(Math.abs(monthlyNetSavings), false) }}
          </text>
          <view class="kpi-footer" v-if="monthlyNetChangePct !== null">
            <view class="trend-pill" :class="monthlyNetChangePct >= 0 ? 'pill-up' : 'pill-down'">
              <text class="trend-arrow">{{ monthlyNetChangePct >= 0 ? '↑' : '↓' }}</text>
              <text>{{ monthlyNetChangePct >= 0 ? '+' : '' }}{{ monthlyNetChangePct.toFixed(1) }}%</text>
            </view>
            <text class="trend-caption">{{ t('reportMonthly.lastMonth') }}</text>
          </view>
        </view>

        <view class="kpi-card kpi-income">
          <view class="kpi-head">
            <view class="kpi-icon-wrap kpi-icon-green">
              <text class="kpi-icon">trending_down</text>
            </view>
            <text class="kpi-label">{{ t('reportMonthly.totalIncomeLabel') }}</text>
          </view>
          <text class="kpi-amount income">+¥ {{ formatAmount(monthlyTotalIncome, false) }}</text>
          <view class="kpi-footer">
            <view v-if="incomeRanking.length > 0" class="cat-mini-list">
              <view v-for="cat in incomeRanking.slice(0, 2)" :key="cat.categoryId" class="cat-mini-row">
                <text class="cat-mini-name">{{ cat.name }}</text>
                <text class="cat-mini-amount">¥{{ formatAmount(cat.total, false) }}</text>
              </view>
            </view>
            <text v-else class="footer-empty">{{ t('reportMonthly.noIncome') }}</text>
          </view>
        </view>

        <view class="kpi-card kpi-expense">
          <view class="kpi-head">
            <view class="kpi-icon-wrap kpi-icon-red">
              <text class="kpi-icon">trending_up</text>
            </view>
            <text class="kpi-label">{{ t('reportMonthly.totalExpenseLabel') }}</text>
          </view>
          <text class="kpi-amount expense">-¥ {{ formatAmount(monthlyTotalExpense, false) }}</text>
          <view class="kpi-footer">
            <text v-if="topExpense" class="footer-text expense">
              {{ t('reportMonthly.topCategoryPrefix') }}{{ topExpense.name }} (¥{{ formatAmount(topExpense.total, false) }})
            </text>
            <text v-else class="footer-empty">{{ t('reportMonthly.noExpense') }}</text>
          </view>
        </view>
      </view>

      <view class="card">
        <text class="card-title">{{ t('reportMonthly.dailyTrend') }}</text>
        <view class="chart-legend">
          <view class="legend-item"><view class="dot income-dot" />{{ t('chart.line.income') }}</view>
          <view class="legend-item"><view class="dot expense-dot" />{{ t('chart.line.expense') }}</view>
        </view>
        <view v-if="monthlyLoading" class="loading">{{ t('common.loading') }}</view>
        <LineChart v-else :data="dailyData" />
      </view>

      <view class="two-col">
        <view class="card">
          <text class="card-title">{{ t('reportMonthly.incomeShare') }}</text>
          <view v-if="incomeDonutSegments.length === 0" class="empty-sm">{{ t('reportMonthly.noIncomeRecords') }}</view>
          <DonutChart v-else :segments="incomeDonutSegments" :total-value="`¥${Math.round(monthlyTotalIncome / 1000)}k`" />
        </view>
        <view class="card">
          <text class="card-title">{{ t('reportMonthly.incomeRanking') }}</text>
          <view v-if="incomeRanking.length === 0" class="empty-sm">{{ t('reportMonthly.noIncomeRecords') }}</view>
          <view v-else class="cat-list">
            <view v-for="cat in incomeRanking" :key="cat.categoryId" class="cat-row">
              <view class="cat-icon" :style="{ background: cat.pres.color + '22' }">
                <text class="cat-icon-text" :style="{ color: cat.pres.color }">{{ cat.pres.icon }}</text>
              </view>
              <text class="cat-name">{{ cat.name }}</text>
              <view class="cat-right">
                <text class="cat-amount">¥{{ formatAmount(cat.total, false) }}</text>
                <text class="cat-pct">{{ monthlyTotalIncome > 0 ? ((cat.total / monthlyTotalIncome) * 100).toFixed(0) : 0 }}%</text>
              </view>
            </view>
          </view>
        </view>
      </view>

      <view class="two-col">
        <view class="card">
          <text class="card-title">{{ t('reportMonthly.expenseShare') }}</text>
          <view v-if="expenseDonutSegments.length === 0" class="empty-sm">{{ t('reportMonthly.noExpenseRecords') }}</view>
          <DonutChart v-else :segments="expenseDonutSegments" :total-value="`¥${Math.round(monthlyTotalExpense / 1000)}k`" />
        </view>
        <view class="card">
          <text class="card-title">{{ t('reportMonthly.expenseRanking') }}</text>
          <view v-if="expenseRanking.length === 0" class="empty-sm">{{ t('reportMonthly.noExpenseRecords') }}</view>
          <view v-else class="cat-list">
            <view v-for="cat in expenseRanking" :key="cat.categoryId" class="cat-row">
              <view class="cat-icon" :style="{ background: cat.pres.color + '22' }">
                <text class="cat-icon-text" :style="{ color: cat.pres.color }">{{ cat.pres.icon }}</text>
              </view>
              <text class="cat-name">{{ cat.name }}</text>
              <view class="cat-right">
                <text class="cat-amount">¥{{ formatAmount(cat.total, false) }}</text>
                <text class="cat-pct">{{ monthlyTotalExpense > 0 ? ((cat.total / monthlyTotalExpense) * 100).toFixed(0) : 0 }}%</text>
              </view>
            </view>
          </view>
        </view>
      </view>
    </template>

    <!-- === Yearly view === -->
    <template v-else>
      <view class="header-row">
        <view class="title-block">
          <text class="page-title">{{ t('reportYearly.title') }}</text>
          <text class="page-subtitle">{{ filterYear }} 年</text>
        </view>
        <view class="year-ctrl">
          <view class="year-btn" @tap="filterYear--; syncYearly()">‹</view>
          <picker mode="selector" :range="yearOptions" :value="yearOptions.indexOf(filterYear)" @change="pickYear">
            <view class="year-label">{{ filterYear }} 年</view>
          </picker>
          <view class="year-btn" @tap="filterYear++; syncYearly()">›</view>
        </view>
      </view>

      <view class="tab-bar">
        <view class="tab" @tap="mode = 'monthly'">{{ t('reportYearly.tabMonthly') }}</view>
        <view class="tab active">{{ t('reportYearly.tabYearly') }}</view>
      </view>

      <view v-if="yearlyError" class="error-box">{{ t('reportYearly.loadErrorPrefix') }}{{ yearlyError }}</view>

      <view class="kpi-list">
        <view class="kpi-card kpi-net">
          <view class="kpi-head">
            <view class="kpi-icon-wrap kpi-icon-blue">
              <text class="kpi-icon">account_balance</text>
            </view>
            <text class="kpi-label">{{ t('reportYearly.netSavingsLabel') }}</text>
          </view>
          <text class="kpi-amount" :class="yearlyNetSavings >= 0 ? 'income' : 'expense'">
            {{ yearlyNetSavings >= 0 ? '' : '-' }}¥ {{ formatAmount(Math.abs(yearlyNetSavings), false) }}
          </text>
        </view>
        <view class="kpi-card kpi-income">
          <view class="kpi-head">
            <view class="kpi-icon-wrap kpi-icon-green">
              <text class="kpi-icon">trending_down</text>
            </view>
            <text class="kpi-label">{{ t('reportYearly.totalIncomeLabel') }}</text>
          </view>
          <text class="kpi-amount income">+¥ {{ formatAmount(yearlyTotalIncome, false) }}</text>
        </view>
        <view class="kpi-card kpi-expense">
          <view class="kpi-head">
            <view class="kpi-icon-wrap kpi-icon-red">
              <text class="kpi-icon">trending_up</text>
            </view>
            <text class="kpi-label">{{ t('reportYearly.totalExpenseLabel') }}</text>
          </view>
          <text class="kpi-amount expense">-¥ {{ formatAmount(yearlyTotalExpense, false) }}</text>
        </view>
      </view>

      <view class="chart-row">
        <view class="card card-bar">
          <text class="card-title">{{ t('reportYearly.monthlyTrend') }}</text>
          <view class="chart-legend">
            <view class="legend-item"><view class="dot income-dot" />{{ t('chart.line.income') }}</view>
            <view class="legend-item"><view class="dot expense-dot" />{{ t('chart.line.expense') }}</view>
          </view>
          <view v-if="yearlyLoading" class="loading">{{ t('common.loading') }}</view>
          <scroll-view v-else scroll-x class="bar-scroll">
            <view class="bar-chart">
              <view v-for="(d, i) in yearlyMonthlyData" :key="i" class="bar-col">
                <view class="bar-group">
                  <view class="bar bar-income" :style="{ height: (yAxisMax > 0 ? (d.income / yAxisMax) * 160 : 0) + 'rpx' }" />
                  <view class="bar bar-expense" :style="{ height: (yAxisMax > 0 ? (d.expense / yAxisMax) * 160 : 0) + 'rpx' }" />
                </view>
                <text class="bar-label">{{ monthLabels[i] }}</text>
              </view>
            </view>
          </scroll-view>
        </view>

        <view class="card card-donut">
          <text class="card-title">{{ t('reportYearly.expenseBreakdown') }}</text>
          <view v-if="yearlyDonutSegments.length === 0" class="empty-sm">{{ t('reportYearly.noExpenseRecords') }}</view>
          <template v-else>
            <DonutChart :segments="yearlyDonutSegments" :total-value="`¥${(yearlyTotalExpense / 1000).toFixed(1)}k`" />
            <view class="cat-list">
              <view v-for="cat in yearlyExpenseByCategory.slice(0, 6)" :key="cat.categoryId" class="cat-row">
                <view class="cat-icon" :style="{ background: cat.pres.color + '22' }">
                  <text class="cat-icon-text" :style="{ color: cat.pres.color }">{{ cat.pres.icon }}</text>
                </view>
                <text class="cat-name">{{ cat.name }}</text>
                <text class="cat-amount">¥{{ formatAmount(cat.total, false) }}</text>
              </view>
            </view>
          </template>
        </view>
      </view>
    </template>
  </view>
</template>

<style scoped>
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.header-row { display: flex; justify-content: space-between; align-items: center; }
.title-block { display: flex; flex-direction: column; gap: 4rpx; }
.page-title { font-size: 36rpx; font-weight: 700; color: var(--c-text); }
.page-subtitle { font-size: 26rpx; color: var(--c-text-variant); }
.month-ctrl { display: flex; align-items: center; gap: 12rpx; }
.year-ctrl { display: flex; align-items: center; gap: 12rpx; }
.year-btn { width: 56rpx; height: 56rpx; border-radius: 28rpx; background: var(--c-surface); display: flex; align-items: center; justify-content: center; font-size: 32rpx; color: var(--c-text-variant); }
.year-label { font-size: 28rpx; font-weight: 600; color: var(--c-text); padding: 8rpx 16rpx; background: var(--c-surface); border-radius: 8rpx; }
.tab-bar { display: flex; background: var(--c-surface); border-radius: 12rpx; padding: 4rpx; gap: 4rpx; }
.tab { flex: 1; text-align: center; padding: 12rpx; border-radius: 8rpx; font-size: 26rpx; color: var(--c-text-variant); }
.tab.active { background: var(--c-bg-card); color: var(--c-primary); font-weight: 600; }
.error-box { background: #FFEBEE; color: #C62828; border-radius: 12rpx; padding: 20rpx; font-size: 26rpx; }
.kpi-list { display: flex; flex-direction: column; gap: 16rpx; }
.kpi-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; display: flex; flex-direction: column; gap: 12rpx; border: 1px solid var(--c-divider); }
.kpi-net { border-left: 4rpx solid var(--c-primary); }
.kpi-income { background: rgba(16, 185, 129, 0.06); border-left: 4rpx solid #10B981; }
.kpi-expense { background: rgba(167, 8, 25, 0.05); border-left: 4rpx solid var(--c-error); }
.kpi-head { display: flex; align-items: center; gap: 12rpx; color: var(--c-text-variant); }
.kpi-icon-wrap { width: 36rpx; height: 36rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.kpi-icon-blue { background: rgba(0, 83, 148, 0.1); }
.kpi-icon-green { background: rgba(16, 185, 129, 0.15); }
.kpi-icon-red { background: rgba(167, 8, 25, 0.12); }
.kpi-icon { font-family: 'Material Symbols Outlined', sans-serif; font-size: 22rpx; font-weight: normal; font-style: normal; }
.kpi-icon-blue .kpi-icon { color: #005394; }
.kpi-icon-green .kpi-icon { color: #10B981; }
.kpi-icon-red .kpi-icon { color: #a70819; }
.kpi-label { font-size: 26rpx; font-weight: 500; color: var(--c-text-variant); }
.kpi-income .kpi-label { color: #10B981; }
.kpi-expense .kpi-label { color: var(--c-error); }
.kpi-amount { font-size: 48rpx; font-weight: 700; color: var(--c-text); }
.kpi-amount.income { color: #10B981; }
.kpi-amount.expense { color: var(--c-error); }
.kpi-footer { display: flex; align-items: center; gap: 8rpx; flex-wrap: wrap; margin-top: 4rpx; }
.trend-pill { display: inline-flex; align-items: center; gap: 4rpx; padding: 4rpx 12rpx; border-radius: 999rpx; font-size: 22rpx; font-weight: 500; }
.pill-up { background: rgba(16, 185, 129, 0.12); color: #047857; }
.pill-down { background: rgba(167, 8, 25, 0.10); color: #B91C1C; }
.trend-arrow { font-size: 22rpx; line-height: 1; }
.trend-caption { font-size: 22rpx; color: var(--c-text-variant); }
.cat-mini-list { display: flex; flex-direction: column; gap: 6rpx; width: 100%; }
.cat-mini-row { display: flex; justify-content: space-between; font-size: 24rpx; }
.cat-mini-name { color: var(--c-text-variant); }
.cat-mini-amount { color: #10B981; font-weight: 600; }
.footer-text { font-size: 24rpx; }
.footer-text.expense { color: var(--c-error); opacity: 0.85; }
.footer-empty { font-size: 24rpx; color: var(--c-text-variant); }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; border: 1px solid var(--c-divider); }
.card-title { font-size: 28rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 16rpx; }
.chart-legend { display: flex; gap: 24rpx; margin-bottom: 12rpx; }
.legend-item { display: flex; align-items: center; gap: 8rpx; font-size: 22rpx; color: var(--c-text-variant); }
.dot { width: 16rpx; height: 16rpx; border-radius: 50%; }
.income-dot { background: #006d40; }
.expense-dot { background: #BA1A1A; }
.expense-dot.yearly { background: #94a3b8; }
.loading { text-align: center; padding: 48rpx; color: var(--c-text-variant); font-size: 26rpx; }
.two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; }
.chart-row { display: flex; flex-direction: column; gap: 16rpx; }
.empty-sm { text-align: center; padding: 32rpx; color: var(--c-text-variant); font-size: 24rpx; }
.cat-list { display: flex; flex-direction: column; gap: 16rpx; }
.cat-row { display: flex; align-items: center; gap: 12rpx; }
.cat-icon { width: 56rpx; height: 56rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.cat-icon.yearly { width: 48rpx; height: 48rpx; }
.cat-icon-text { font-size: 24rpx; font-family: 'Material Symbols Outlined', sans-serif; font-weight: normal; font-style: normal; }
.cat-icon-text.yearly { font-size: 20rpx; }
.cat-name { flex: 1; font-size: 26rpx; color: var(--c-text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cat-name.yearly { font-size: 24rpx; }
.cat-right { display: flex; flex-direction: column; align-items: flex-end; gap: 2rpx; }
.cat-amount { font-size: 26rpx; font-weight: 600; color: var(--c-text); }
.cat-amount.yearly { font-size: 24rpx; }
.cat-pct { font-size: 22rpx; color: var(--c-text-variant); }
.bar-scroll { width: 100%; }
.bar-chart { display: flex; align-items: flex-end; gap: 8rpx; height: 220rpx; padding-bottom: 40rpx; }
.bar-col { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 4rpx; height: 100%; justify-content: flex-end; }
.bar-group { display: flex; gap: 2rpx; align-items: flex-end; height: 160rpx; }
.bar { width: 20rpx; border-radius: 4rpx 4rpx 0 0; min-height: 4rpx; }
.bar-income { background: #006d40; }
.bar-expense { background: #94a3b8; }
.bar-label { font-size: 18rpx; color: var(--c-text-variant); margin-top: 8rpx; }
.card-donut { display: flex; flex-direction: column; }
</style>