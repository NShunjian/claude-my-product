<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useBookStore } from '@/stores/book'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { getMonthlyReport } from '@/api/reports'
import { categoryPresentation } from '@/utils/category-presentation'
import { formatAmount } from '@/utils/finance'
import MonthPicker from '@/components/MonthPicker.vue'
import LineChart from '@/components/charts/LineChart.vue'
import DonutChart from '@/components/DonutChart.vue'
import type { MonthlyReport, DailyPoint } from '@/api/reports'

const book = useBookStore()
const auth = useAuthStore()
const toast = useToastStore()
const { t } = useLanguage()

function currentMonth(): string {
  const d = new Date()
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
}

function shiftMonth(month: string, delta: number): string {
  const [y, m] = month.split('-').map(Number)
  const d = new Date(y, m - 1 + delta, 1)
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
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

const filterMonth = ref(currentMonth())
const report = ref<MonthlyReport | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)

const dailyData = computed(() => report.value ? fillDailyData(report.value) : [])
const totalIncome = computed(() => report.value?.totalIncome ?? 0)
const totalExpense = computed(() => report.value?.totalExpense ?? 0)
const netSavings = computed(() => report.value?.netSavings ?? 0)

const lastMonth = computed(() => report.value?.lastMonth ?? null)
const netChangePct = computed(() => {
  if (!lastMonth.value || lastMonth.value.netSavings === 0) return null
  return ((netSavings.value - lastMonth.value.netSavings) / Math.abs(lastMonth.value.netSavings)) * 100
})

const incomeRanking = computed(() => {
  if (!report.value) return []
  return [...report.value.incomeByCategory].sort((a, b) => b.total - a.total)
    .map((c) => ({ ...c, pres: categoryPresentation({ id: c.categoryId, type: 'income', name: c.name }) }))
})

const expenseRanking = computed(() => {
  if (!report.value) return []
  return [...report.value.expenseByCategory].sort((a, b) => b.total - a.total)
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

async function load() {
  if (!auth.token || !book.current) return
  loading.value = true
  error.value = null
  try {
    report.value = await getMonthlyReport(filterMonth.value, book.current.uuid)
  } catch (e: any) {
    error.value = e?.message ?? '加载失败'
  } finally {
    loading.value = false
  }
}

function goPrev() { filterMonth.value = shiftMonth(filterMonth.value, -1) }
function goNext() { filterMonth.value = shiftMonth(filterMonth.value, 1) }

watch([filterMonth, () => book.current], load, { immediate: true })
onShow(load)
</script>

<template>
  <view class="page">
    <!-- Header + month picker + tab switch -->
    <view class="header-row">
      <view class="title-block">
        <text class="page-title">{{ t('reportMonthly.title') }}</text>
        <text class="page-subtitle">{{ filterMonth.slice(0, 4) }} 年 {{ Number(filterMonth.slice(5)) }} 月</text>
      </view>
      <view class="month-ctrl">
        <view class="month-btn" @tap="goPrev">‹</view>
        <MonthPicker v-model="filterMonth" />
        <view class="month-btn" @tap="goNext">›</view>
      </view>
    </view>

    <!-- Tab switch -->
    <view class="tab-bar">
      <view class="tab active">{{ t('reportMonthly.tabMonthly') }}</view>
      <view class="tab" @tap="uni.navigateTo({ url: '/pages/reports/yearly' })">{{ t('reportMonthly.tabYearly') }}</view>
    </view>

    <!-- Error -->
    <view v-if="error" class="error-box">{{ t('reportMonthly.loadErrorPrefix') }}{{ error }}</view>

    <!-- KPI cards -->
    <view class="kpi-grid">
      <view class="kpi-card kpi-net">
        <view class="kpi-label">{{ t('reportMonthly.netSavings') }}</view>
        <text class="kpi-amount" :class="netSavings >= 0 ? 'income' : 'expense'">
          {{ netSavings >= 0 ? '' : '-' }}¥ {{ formatAmount(Math.abs(netSavings), false) }}
        </text>
        <view class="kpi-trend" v-if="netChangePct !== null">
          <text :class="netChangePct >= 0 ? 'income' : 'expense'">
            {{ netChangePct >= 0 ? '↑' : '↓' }} {{ Math.abs(netChangePct).toFixed(1) }}%
          </text>
          <text class="trend-label">{{ t('reportMonthly.lastMonth') }}</text>
        </view>
      </view>

      <view class="kpi-card kpi-income">
        <view class="kpi-label">{{ t('reportMonthly.totalIncomeLabel') }}</view>
        <text class="kpi-amount income">+¥ {{ formatAmount(totalIncome, false) }}</text>
        <view class="kpi-top">
          <text v-if="incomeRanking[0]" class="top-label">{{ incomeRanking[0].name }} ¥{{ formatAmount(incomeRanking[0].total, false) }}</text>
          <text v-else class="top-label income">{{ t('reportMonthly.noIncome') }}</text>
        </view>
      </view>

      <view class="kpi-card kpi-expense">
        <view class="kpi-label">{{ t('reportMonthly.totalExpenseLabel') }}</view>
        <text class="kpi-amount expense">-¥ {{ formatAmount(totalExpense, false) }}</text>
        <view class="kpi-top">
          <text v-if="topExpense" class="top-label">{{ t('reportMonthly.topCategoryPrefix') }}{{ topExpense.name }} ¥{{ formatAmount(topExpense.total, false) }}</text>
          <text v-else class="top-label expense">{{ t('reportMonthly.noExpense') }}</text>
        </view>
      </view>
    </view>

    <!-- Daily trend -->
    <view class="card">
      <text class="card-title">{{ t('reportMonthly.dailyTrend') }}</text>
      <view class="chart-legend">
        <view class="legend-item"><view class="dot income-dot" />{{ t('chart.line.income') }}</view>
        <view class="legend-item"><view class="dot expense-dot" />{{ t('chart.line.expense') }}</view>
      </view>
      <view v-if="loading" class="loading">{{ t('common.loading') }}</view>
      <LineChart v-else :data="dailyData" />
    </view>

    <!-- Income share + ranking -->
    <view class="two-col">
      <view class="card">
        <text class="card-title">{{ t('reportMonthly.incomeShare') }}</text>
        <view v-if="incomeDonutSegments.length === 0" class="empty-sm">{{ t('reportMonthly.noIncomeRecords') }}</view>
        <DonutChart v-else :segments="incomeDonutSegments" :total-value="`¥${Math.round(totalIncome / 1000)}k`" />
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
              <text class="cat-pct">{{ totalIncome > 0 ? ((cat.total / totalIncome) * 100).toFixed(0) : 0 }}%</text>
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- Expense share + ranking -->
    <view class="two-col">
      <view class="card">
        <text class="card-title">{{ t('reportMonthly.expenseShare') }}</text>
        <view v-if="expenseDonutSegments.length === 0" class="empty-sm">{{ t('reportMonthly.noExpenseRecords') }}</view>
        <DonutChart v-else :segments="expenseDonutSegments" :total-value="`¥${Math.round(totalExpense / 1000)}k`" />
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
              <text class="cat-pct">{{ totalExpense > 0 ? ((cat.total / totalExpense) * 100).toFixed(0) : 0 }}%</text>
            </view>
          </view>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.header-row { display: flex; justify-content: space-between; align-items: center; }
.title-block { display: flex; flex-direction: column; gap: 4rpx; }
.page-title { font-size: 36rpx; font-weight: 700; color: var(--c-text); }
.page-subtitle { font-size: 26rpx; color: var(--c-text-variant); }
.month-ctrl { display: flex; align-items: center; gap: 12rpx; }
.month-btn { width: 56rpx; height: 56rpx; border-radius: 28rpx; background: var(--c-surface); display: flex; align-items: center; justify-content: center; font-size: 32rpx; color: var(--c-text-variant); }
.tab-bar { display: flex; background: var(--c-surface); border-radius: 12rpx; padding: 4rpx; gap: 4rpx; }
.tab { flex: 1; text-align: center; padding: 12rpx; border-radius: 8rpx; font-size: 26rpx; color: var(--c-text-variant); }
.tab.active { background: var(--c-bg-card); color: var(--c-primary); font-weight: 600; }
.error-box { background: #FFEBEE; color: #C62828; border-radius: 12rpx; padding: 20rpx; font-size: 26rpx; }
.kpi-grid { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16rpx; }
.kpi-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 20rpx; display: flex; flex-direction: column; gap: 8rpx; border: 1px solid var(--c-divider); }
.kpi-net { border-left: 4rpx solid var(--c-primary); }
.kpi-income { border-left: 4rpx solid #10B981; }
.kpi-expense { border-left: 4rpx solid var(--c-error); }
.kpi-label { font-size: 22rpx; color: var(--c-text-variant); }
.kpi-amount { font-size: 32rpx; font-weight: 700; }
.kpi-amount.income { color: #10B981; }
.kpi-amount.expense { color: var(--c-error); }
.kpi-trend { display: flex; align-items: center; gap: 8rpx; font-size: 22rpx; }
.trend-label { color: var(--c-text-variant); }
.kpi-top { margin-top: auto; }
.top-label { font-size: 20rpx; color: var(--c-text-variant); }
.top-label.income { color: #10B981; }
.top-label.expense { color: var(--c-error); }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; border: 1px solid var(--c-divider); }
.card-title { font-size: 28rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 16rpx; }
.chart-legend { display: flex; gap: 24rpx; margin-bottom: 12rpx; }
.legend-item { display: flex; align-items: center; gap: 8rpx; font-size: 22rpx; color: var(--c-text-variant); }
.dot { width: 16rpx; height: 16rpx; border-radius: 50%; }
.income-dot { background: #006d40; }
.expense-dot { background: #BA1A1A; }
.loading { text-align: center; padding: 48rpx; color: var(--c-text-variant); font-size: 26rpx; }
.two-col { display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; }
.empty-sm { text-align: center; padding: 32rpx; color: var(--c-text-variant); font-size: 24rpx; }
.cat-list { display: flex; flex-direction: column; gap: 16rpx; }
.cat-row { display: flex; align-items: center; gap: 12rpx; }
.cat-icon { width: 56rpx; height: 56rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.cat-icon-text { font-size: 24rpx; font-family: 'Material Symbols Outlined', sans-serif; font-weight: normal; font-style: normal; }
.cat-name { flex: 1; font-size: 26rpx; color: var(--c-text); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.cat-right { display: flex; flex-direction: column; align-items: flex-end; gap: 2rpx; }
.cat-amount { font-size: 26rpx; font-weight: 600; color: var(--c-text); }
.cat-pct { font-size: 22rpx; color: var(--c-text-variant); }
</style>
