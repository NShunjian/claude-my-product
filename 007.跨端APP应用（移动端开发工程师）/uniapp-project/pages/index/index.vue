<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useBookStore } from '@/stores/book'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { listRecords } from '@/api/records'
import { listAccounts } from '@/api/accounts'
import { listCategories } from '@/api/categories'
import TransactionRow from '@/components/TransactionRow.vue'
import MonthPicker from '@/components/MonthPicker.vue'
import type { Record } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import { formatAmount } from '@/utils/finance'
import { formatLocalMonth, compareRecordDesc } from '@/utils/date'

const book = useBookStore()
const auth = useAuthStore()
const toast = useToastStore()
const { t } = useLanguage()

const month = ref(formatLocalMonth(new Date()))
const records = ref<Record[]>([])
const accounts = ref<Account[]>([])
const cats = ref<Category[]>([])
const loading = ref(false)

const monthIncome = computed(() =>
  records.value.filter(r => r.type === 'income').reduce((s, r) => s + r.amount, 0)
)
const monthExpense = computed(() =>
  records.value.filter(r => r.type === 'expense').reduce((s, r) => s + r.amount, 0)
)
const monthBalance = computed(() => monthIncome.value - monthExpense.value)
const totalAssets = computed(() => accounts.value.reduce((s, a) => s + a.balance, 0))

const recentRecords = computed(() => [...records.value].sort(compareRecordDesc).slice(0, 5))

// Group records by date
const grouped = computed(() => {
  const map = new Map<string, Record[]>()
  for (const r of recentRecords.value) {
    if (!r || !r.id) continue
    const arr = map.get(r.recordDate) ?? []
    arr.push(r)
    map.set(r.recordDate, arr)
  }
  return Array.from(map.entries()).map(([date, recs]) => ({
    date,
    recs,
    net: recs.reduce((s, r) => s + (r.type === 'income' ? r.amount : -r.amount), 0),
  }))
})

function findAccount(id: string) { return accounts.value.find(a => a.id === id) }
function findCat(id: string | null) { return cats.value.find(c => c.id === id) }

async function load() {
  if (!auth.token || !book.current) return
  loading.value = true
  try {
    const [recs, accts, catsExpense, catsIncome] = await Promise.all([
      listRecords({ month: month.value, bookId: book.current.uuid }),
      listAccounts({ bookId: book.current.uuid }),
      listCategories('expense'),
      listCategories('income'),
    ])
    records.value = recs
    accounts.value = accts
    cats.value = [...catsExpense, ...catsIncome]
  } catch (e: any) {
    toast.show(t('home.loadErrorPrefix') + (e?.message ?? ''))
  } finally {
    loading.value = false
  }
}

// 监听 book.current 与 auth.token:任一变化且都已就绪时拉数据。
// 解决了"挂载早于 reload 完成"的竞态 —— 之前 onMounted(load) 跑时 book.current 经常还是 null,
// 直接 return,后面 reload 完成了也没人再触发一次。
watch(
  [() => auth.token, () => book.current],
  () => { load() },
  { immediate: true },
)

// 切回 tabBar 页时重新拉数据(uni-app 不会重新挂载,只有 watch+immediate 不够)
onShow(load)
</script>

<template>
  <view class="page">
    <!-- Header -->
    <view class="header">
      <view class="greeting">
        <text class="title">{{ t('home.overview') }}</text>
        <text class="subtitle">{{ month.slice(0, 4) }}/{{ month.slice(5, 7) }}</text>
      </view>
      <MonthPicker v-model="month" @update:model-value="load" />
    </view>

    <!-- Total Assets -->
    <view class="card assets-card">
      <text class="card-label">{{ t('home.totalAssets') }}</text>
      <text class="assets-amount">¥ {{ formatAmount(totalAssets) }}</text>
      <text class="card-sub">{{ t('home.accountsCount').replace('{n}', String(accounts.length)) }}</text>
    </view>

    <!-- KPI Row -->
    <view class="kpi-row">
      <view class="kpi-card expense">
        <text class="kpi-label">{{ t('home.monthExpense') }}</text>
        <text class="kpi-amount expense">-¥ {{ formatAmount(monthExpense) }}</text>
      </view>
      <view class="kpi-card income">
        <text class="kpi-label">{{ t('home.monthIncome') }}</text>
        <text class="kpi-amount income">+¥ {{ formatAmount(monthIncome) }}</text>
      </view>
      <view class="kpi-card balance">
        <text class="kpi-label">{{ t('home.monthBalance') }}</text>
        <text class="kpi-amount" :class="monthBalance >= 0 ? 'income' : 'expense'">
          {{ monthBalance >= 0 ? '+' : '-' }}¥ {{ formatAmount(Math.abs(monthBalance)) }}
        </text>
        <text class="kpi-badge">{{ monthBalance >= 0 ? t('home.surplus') : t('home.overBudget') }}</text>
      </view>
    </view>

    <!-- Quick Add -->
    <view class="quick-add">
      <button class="quick-btn expense-btn" @tap="uni.navigateTo({ url: '/pages/record/expense' })">
        {{ t('recordExpense.submit') }}支出
      </button>
      <button class="quick-btn income-btn" @tap="uni.navigateTo({ url: '/pages/record/income' })">
        {{ t('recordIncome.submit') }}收入
      </button>
    </view>

    <!-- Recent Transactions -->
    <view class="card">
      <view class="card-head">
        <text class="card-title">{{ t('home.recentTransactions') }}</text>
        <text class="view-all" @tap="uni.switchTab({ url: '/pages/transactions/index' })">{{ t('home.viewAll') }} ›</text>
      </view>
      <view v-if="loading" class="empty">{{ t('home.loading') }}</view>
      <view v-else-if="records.length === 0" class="empty">{{ t('home.empty') }}</view>
      <view v-else>
        <view v-for="group in grouped" :key="group.date" class="day-group">
          <view class="day-header">
            <text class="day-label">{{ group.date }}</text>
            <text class="day-net" :class="group.net >= 0 ? 'income' : 'expense'">
              {{ group.net >= 0 ? '+' : '-' }}¥ {{ formatAmount(Math.abs(group.net)) }}
            </text>
          </view>
          <TransactionRow
            v-for="(r, idx) in group.recs"
            :key="r?.id ?? `row-${group.date}-${idx}`"
            :record="r"
            :category="findCat(r.categoryId)"
            @tap="() => {}"
          />
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.header { display: flex; justify-content: space-between; align-items: center; }
.greeting { display: flex; flex-direction: column; gap: 4rpx; }
.title { font-size: 36rpx; font-weight: 700; }
.subtitle { font-size: 26rpx; color: var(--c-text-variant); }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; }
.card-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16rpx; }
.card-title { font-size: 30rpx; font-weight: 600; }
.view-all { font-size: 26rpx; color: var(--c-primary); }
.card-label { font-size: 24rpx; color: var(--c-text-variant); display: block; margin-bottom: 8rpx; }
.assets-card { background: linear-gradient(135deg, var(--c-primary-light, #e3f2fd), var(--c-bg-card)); }
.assets-amount { font-size: 48rpx; font-weight: 700; color: var(--c-primary); display: block; }
.card-sub { font-size: 24rpx; color: var(--c-text-variant); margin-top: 8rpx; display: block; }
.kpi-row { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 16rpx; }
.kpi-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 20rpx; display: flex; flex-direction: column; gap: 8rpx; }
.kpi-label { font-size: 22rpx; color: var(--c-text-variant); }
.kpi-amount { font-size: 28rpx; font-weight: 700; }
.kpi-badge { font-size: 20rpx; color: var(--c-text-variant); }
.expense { color: var(--c-error); }
.income { color: #2E7DE6; }
.quick-add { display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; }
.quick-btn { border-radius: 12rpx; padding: 24rpx; font-size: 30rpx; font-weight: 600; color: #fff; }
.expense-btn { background: var(--c-error); }
.income-btn { background: #2E7DE6; }
.empty { text-align: center; padding: 48rpx; color: var(--c-text-variant); font-size: 28rpx; }
.day-group { border-bottom: 1px solid var(--c-divider); }
.day-group:last-child { border-bottom: none; }
.day-header { display: flex; justify-content: space-between; padding: 12rpx 16rpx; background: var(--c-surface); }
.day-label { font-size: 24rpx; font-weight: 600; color: var(--c-text-variant); }
.day-net { font-size: 24rpx; font-weight: 600; }
</style>
