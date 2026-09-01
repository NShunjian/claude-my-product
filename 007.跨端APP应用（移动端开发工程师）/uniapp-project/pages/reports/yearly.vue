<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useBookStore } from '@/stores/book'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { getYearlyReport } from '@/api/reports'
import { categoryIconColor } from '@/utils/category-presentation'
import { formatAmount } from '@/utils/finance'
import DonutChart from '@/components/DonutChart.vue'
import type { YearlyReport, MonthlyPoint, CategoryTotal } from '@/api/reports'

const book = useBookStore()
const auth = useAuthStore()
const toast = useToastStore()
const { t } = useLanguage()

function currentYear(): number {
  return new Date().getFullYear()
}

const filterYear = ref(currentYear())
const report = ref<YearlyReport | null>(null)
const loading = ref(false)
const error = ref<string | null>(null)

function fillMonthlyData(report: YearlyReport): MonthlyPoint[] {
  const byMonth = new Map(report.monthlyData.map((d) => [d.month, d]))
  return Array.from({ length: 12 }, (_, i) => {
    const month = i + 1
    return byMonth.get(month) ?? { month, income: 0, expense: 0 }
  })
}

const monthlyData = computed(() => report.value ? fillMonthlyData(report.value) : [])

const totalIncome = computed(() => report.value?.totalIncome ?? 0)
const totalExpense = computed(() => report.value?.totalExpense ?? 0)
const netSavings = computed(() => report.value?.netSavings ?? 0)

const expenseByCategory = computed(() => {
  if (!report.value) return []
  return [...report.value.expenseByCategory].sort((a, b) => b.total - a.total)
})

const donutSegments = computed(() =>
  expenseByCategory.value.map((cat) => ({
    label: cat.name,
    value: cat.total,
    color: categoryIconColor(cat.icon ?? 'receipt', cat.color ?? '#999').color,
  }))
)

const monthLabels = computed(() => [
  t('reportYearly.monthJan'), t('reportYearly.monthFeb'), t('reportYearly.monthMar'),
  t('reportYearly.monthApr'), t('reportYearly.monthMay'), t('reportYearly.monthJun'),
  t('reportYearly.monthJul'), t('reportYearly.monthAug'), t('reportYearly.monthSep'),
  t('reportYearly.monthOct'), t('reportYearly.monthNov'), t('reportYearly.monthDec'),
])

// Y-axis max for bar chart
const yAxisMax = computed(() => {
  const raw = Math.max(...monthlyData.value.map((d) => Math.max(d.income, d.expense)), 0)
  return Math.ceil(raw / 5000) * 5000 || 10000
})

async function load() {
  if (!auth.token || !book.current) return
  loading.value = true
  error.value = null
  try {
    report.value = await getYearlyReport(filterYear.value, book.current.uuid)
  } catch (e: any) {
    error.value = e?.message ?? '加载失败'
  } finally {
    loading.value = false
  }
}

watch([filterYear, () => book.current], load, { immediate: true })
onShow(load)
</script>

<template>
  <view class="page">
    <!-- Header + year picker -->
    <view class="header-row">
      <view class="title-block">
        <text class="page-title">{{ t('reportYearly.title') }}</text>
        <text class="page-subtitle">{{ filterYear }} 年</text>
      </view>
      <view class="year-ctrl">
        <view class="year-btn" @tap="filterYear--; load()">‹</view>
        <picker mode="selector" :range="Array.from({ length: 10 }, (_, i) => new Date().getFullYear() - 5 + i)" :value="filterYear - (new Date().getFullYear() - 5)" @change="(e: any) => { filterYear = Number(e.detail.value) + new Date().getFullYear() - 5; load() }">
          <view class="year-label">{{ filterYear }} 年</view>
        </picker>
        <view class="year-btn" @tap="filterYear++; load()">›</view>
      </view>
    </view>

    <!-- Tab switch -->
    <view class="tab-bar">
      <view class="tab" @tap="uni.switchTab({ url: '/pages/reports/monthly' })">{{ t('reportYearly.tabMonthly') }}</view>
      <view class="tab active">{{ t('reportYearly.tabYearly') }}</view>
    </view>

    <!-- Error -->
    <view v-if="error" class="error-box">{{ t('reportYearly.loadErrorPrefix') }}{{ error }}</view>

    <!-- KPI cards -->
    <view class="kpi-grid">
      <view class="kpi-card kpi-net">
        <view class="kpi-label">{{ t('reportYearly.netSavingsLabel') }}</view>
        <text class="kpi-amount" :class="netSavings >= 0 ? 'income' : 'expense'">
          {{ netSavings >= 0 ? '' : '-' }}¥ {{ formatAmount(Math.abs(netSavings), false) }}
        </text>
      </view>
      <view class="kpi-card kpi-income">
        <view class="kpi-label">{{ t('reportYearly.totalIncomeLabel') }}</view>
        <text class="kpi-amount income">+¥ {{ formatAmount(totalIncome, false) }}</text>
      </view>
      <view class="kpi-card kpi-expense">
        <view class="kpi-label">{{ t('reportYearly.totalExpenseLabel') }}</view>
        <text class="kpi-amount expense">-¥ {{ formatAmount(totalExpense, false) }}</text>
      </view>
    </view>

    <!-- Monthly bars + donut -->
    <view class="chart-row">
      <view class="card card-bar">
        <text class="card-title">{{ t('reportYearly.monthlyTrend') }}</text>
        <view class="chart-legend">
          <view class="legend-item"><view class="dot income-dot" />{{ t('chart.line.income') }}</view>
          <view class="legend-item"><view class="dot expense-dot" />{{ t('chart.line.expense') }}</view>
        </view>
        <view v-if="loading" class="loading">{{ t('common.loading') }}</view>
        <scroll-view v-else scroll-x class="bar-scroll">
          <view class="bar-chart">
            <view v-for="(d, i) in monthlyData" :key="i" class="bar-col">
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
        <view v-if="donutSegments.length === 0" class="empty-sm">{{ t('reportYearly.noExpenseRecords') }}</view>
        <template v-else>
          <DonutChart :segments="donutSegments" :total-value="`¥${(totalExpense / 1000).toFixed(1)}k`" />
          <view class="cat-list">
            <view v-for="cat in expenseByCategory.slice(0, 6)" :key="cat.categoryId" class="cat-row">
              <view class="cat-icon" :style="{ background: categoryIconColor(cat.icon, cat.color).color + '22' }">
                <text class="cat-icon-text" :style="{ color: categoryIconColor(cat.icon, cat.color).color }">{{ cat.icon }}</text>
              </view>
              <text class="cat-name">{{ cat.name }}</text>
              <text class="cat-amount">¥{{ formatAmount(cat.total, false) }}</text>
            </view>
          </view>
        </template>
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
.year-ctrl { display: flex; align-items: center; gap: 12rpx; }
.year-btn { width: 56rpx; height: 56rpx; border-radius: 28rpx; background: var(--c-surface); display: flex; align-items: center; justify-content: center; font-size: 32rpx; color: var(--c-text-variant); }
.year-label { font-size: 28rpx; font-weight: 600; color: var(--c-text); padding: 8rpx 16rpx; background: var(--c-surface); border-radius: 8rpx; }
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
.chart-row { display: flex; flex-direction: column; gap: 16rpx; }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; border: 1px solid var(--c-divider); }
.card-title { font-size: 28rpx; font-weight: 600; color: var(--c-text); display: block; margin-bottom: 16rpx; }
.chart-legend { display: flex; gap: 24rpx; margin-bottom: 12rpx; }
.legend-item { display: flex; align-items: center; gap: 8rpx; font-size: 22rpx; color: var(--c-text-variant); }
.dot { width: 16rpx; height: 16rpx; border-radius: 50%; }
.income-dot { background: #006d40; }
.expense-dot { background: #94a3b8; }
.loading { text-align: center; padding: 48rpx; color: var(--c-text-variant); font-size: 26rpx; }
.bar-scroll { width: 100%; }
.bar-chart { display: flex; align-items: flex-end; gap: 8rpx; height: 220rpx; padding-bottom: 40rpx; }
.bar-col { flex: 1; display: flex; flex-direction: column; align-items: center; gap: 4rpx; height: 100%; justify-content: flex-end; }
.bar-group { display: flex; gap: 2rpx; align-items: flex-end; height: 160rpx; }
.bar { width: 20rpx; border-radius: 4rpx 4rpx 0 0; min-height: 4rpx; }
.bar-income { background: #006d40; }
.bar-expense { background: #94a3b8; }
.bar-label { font-size: 18rpx; color: var(--c-text-variant); margin-top: 8rpx; }
.card-donut { display: flex; flex-direction: column; }
.empty-sm { text-align: center; padding: 32rpx; color: var(--c-text-variant); font-size: 24rpx; }
.cat-list { margin-top: 16rpx; display: flex; flex-direction: column; gap: 12rpx; }
.cat-row { display: flex; align-items: center; gap: 12rpx; }
.cat-icon { width: 48rpx; height: 48rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.cat-icon-text { font-size: 20rpx; }
.cat-name { flex: 1; font-size: 24rpx; color: var(--c-text); }
.cat-amount { font-size: 24rpx; font-weight: 600; color: var(--c-text); }
</style>
