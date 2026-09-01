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
import QuickAddModal from '@/components/QuickAddModal.vue'
import type { Record } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import { formatAmount } from '@/utils/finance'
import { formatLocalMonth, compareRecordDesc, formatMonthCN, formatRelativeDayLabel } from '@/utils/date'

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
  const today = new Date()
  const labels = { today: t('home.today'), yesterday: t('home.yesterday') }
  return Array.from(map.entries()).map(([date, recs]) => ({
    date,
    recs,
    net: recs.reduce((s, r) => s + (r.type === 'income' ? r.amount : -r.amount), 0),
    label: formatRelativeDayLabel(date, today, labels),
  }))
})

const subtitle = computed(() => formatMonthCN(month.value))

// 分类汇总:本月按分类聚合,降序,0 金额仍在底部展示(对齐 React CategoryBreakdown)
const expenseCats = computed(() => cats.value.filter(c => c.type === 'expense'))
const incomeCats = computed(() => cats.value.filter(c => c.type === 'income'))
const expenseByCat = computed(() => expenseCats.value.map(c => ({
  cat: c,
  total: records.value.filter(r => r.type === 'expense' && r.categoryId === c.id).reduce((s, r) => s + r.amount, 0),
})).sort((a, b) => b.total - a.total))
const incomeByCat = computed(() => incomeCats.value.map(c => ({
  cat: c,
  total: records.value.filter(r => r.type === 'income' && r.categoryId === c.id).reduce((s, r) => s + r.amount, 0),
})).sort((a, b) => b.total - a.total))

function findAccount(id: string) { return accounts.value.find(a => a.id === id) }
function findCat(id: string | null) { return cats.value.find(c => c.id === id) }

const showQuickAdd = ref(false)
const quickAddKind = ref<'expense' | 'income'>('expense')

function onQuickAdd() {
  quickAddKind.value = 'expense'
  showQuickAdd.value = true
}

function onQuickAddSaved() {
  // 弹框关闭 + 数据落库后,重新拉当前月流水与账户余额
  load()
}

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
        <text class="subtitle">{{ subtitle }}</text>
      </view>
      <MonthPicker v-model="month" @update:model-value="load" />
    </view>

    <!-- Total Assets -->
    <view class="card assets-card">
      <text class="wallet-icon">💰</text>
      <text class="card-label">{{ t('home.totalAssets') }}</text>
      <view class="amount-row">
        <text class="amt-symbol primary">¥</text>
        <text class="amt-big primary">{{ formatAmount(totalAssets) }}</text>
      </view>
      <text class="card-sub">{{ t('home.accountsCount').replace('{n}', String(accounts.length)) }}</text>
      <button class="quick-add-btn" @tap="onQuickAdd">{{ t('home.quickAdd') }}</button>
    </view>

    <!-- KPI Stack -->
    <view class="kpi-stack">
      <view class="card kpi-card">
        <text class="card-label">{{ t('home.monthExpense') }}</text>
        <view class="amount-row">
          <text class="amt-symbol expense">¥</text>
          <text class="amt-big expense">{{ formatAmount(monthExpense) }}</text>
        </view>
      </view>
      <view class="card kpi-card">
        <text class="card-label">{{ t('home.monthIncome') }}</text>
        <view class="amount-row">
          <text class="amt-symbol income">¥</text>
          <text class="amt-big income">{{ formatAmount(monthIncome) }}</text>
        </view>
      </view>
      <view class="card kpi-card balance-card">
        <text class="card-label">{{ t('home.monthBalance') }}</text>
        <view class="amount-row">
          <text class="amt-symbol" :class="monthBalance >= 0 ? 'income' : 'expense'">
            ¥
          </text>
          <text class="amt-big" :class="monthBalance >= 0 ? 'income' : 'expense'">
            {{ formatAmount(Math.abs(monthBalance)) }}
          </text>
        </view>
        <text class="card-sub balance-sub" :class="monthBalance >= 0 ? 'income' : 'expense'">
          {{ monthBalance >= 0 ? t('home.surplus') : t('home.overBudget') }}
        </text>
      </view>
    </view>

    <!-- Recent Transactions -->
    <view class="card">
      <view class="card-head">
        <text class="card-title">{{ t('home.recentTransactions') }}</text>
        <text class="view-all" @tap="uni.switchTab({ url: '/pages/transactions/index' })">{{ t('home.viewAll') }} →</text>
      </view>
      <view v-if="loading" class="empty">{{ t('home.loading') }}</view>
      <view v-else-if="records.length === 0" class="empty">{{ t('home.empty') }}</view>
      <view v-else>
        <view v-for="group in grouped" :key="group.date" class="day-group">
          <view class="day-header">
            <text class="day-label">{{ group.label }}</text>
            <text class="day-net">
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

    <!-- Category breakdown -->
    <view class="breakdown-row">
      <view class="card breakdown-card">
        <text class="card-title">{{ t('home.expenseByCategory') }}</text>
        <view v-if="expenseByCat.length === 0" class="empty-mini">{{ t('home.empty') }}</view>
        <view v-else class="cat-list">
          <view v-for="row in expenseByCat" :key="row.cat.id" class="cat-row">
            <view class="cat-line">
              <view class="cat-id">
                <view class="cat-icon" :style="{ background: row.cat.color + '33' }">
                  <text class="cat-icon-text">{{ row.cat.icon }}</text>
                </view>
                <text class="cat-name">{{ row.cat.name }}</text>
              </view>
              <text class="cat-amt">¥ {{ formatAmount(row.total) }}</text>
            </view>
            <view class="cat-bar-track">
              <view class="cat-bar-fill" :style="{
                width: (monthExpense > 0 ? (row.total / monthExpense) * 100 : 0) + '%',
                background: row.cat.color,
              }" />
            </view>
          </view>
        </view>
      </view>

      <view class="card breakdown-card">
        <text class="card-title">{{ t('home.incomeByCategory') }}</text>
        <view v-if="incomeByCat.length === 0" class="empty-mini">{{ t('home.empty') }}</view>
        <view v-else class="cat-list">
          <view v-for="row in incomeByCat" :key="row.cat.id" class="cat-row">
            <view class="cat-line">
              <view class="cat-id">
                <view class="cat-icon" :style="{ background: row.cat.color + '33' }">
                  <text class="cat-icon-text">{{ row.cat.icon }}</text>
                </view>
                <text class="cat-name">{{ row.cat.name }}</text>
              </view>
              <text class="cat-amt">¥ {{ formatAmount(row.total) }}</text>
            </view>
            <view class="cat-bar-track">
              <view class="cat-bar-fill" :style="{
                width: (monthIncome > 0 ? (row.total / monthIncome) * 100 : 0) + '%',
                background: row.cat.color,
              }" />
            </view>
          </view>
        </view>
      </view>
    </view>

    <!-- Quick Add Modal -->
    <QuickAddModal
      v-model:show="showQuickAdd"
      :kind="quickAddKind"
      :categories="cats"
      :accounts="accounts"
      @saved="onQuickAddSaved"
    />
  </view>
</template>

<style scoped>
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.header { display: flex; justify-content: space-between; align-items: center; }
.greeting { display: flex; flex-direction: column; gap: 4rpx; }
.title { font-size: 36rpx; font-weight: 700; }
.subtitle { font-size: 26rpx; color: var(--c-text-variant); }
.card { background: var(--c-bg-card); border: 1px solid var(--c-divider); border-radius: 16rpx; padding: 24rpx; }
.card-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16rpx; }
.card-title { font-size: 30rpx; font-weight: 600; }
.view-all { font-size: 26rpx; color: var(--c-primary); }
.card-label { font-size: 26rpx; color: var(--c-text-variant); display: block; margin-bottom: 12rpx; }
.assets-card { position: relative; overflow: hidden; }
.wallet-icon { position: absolute; top: 24rpx; right: 24rpx; font-size: 96rpx; opacity: 0.12; line-height: 1; }
.amount-row { display: flex; align-items: baseline; gap: 6rpx; }
.amt-symbol { font-size: 32rpx; font-weight: 600; line-height: 1; }
.amt-big { font-size: 56rpx; font-weight: 700; line-height: 1.1; }
.amt-big.primary { color: var(--c-primary); }
.amt-symbol.primary { color: var(--c-primary); }
.card-sub { font-size: 24rpx; color: var(--c-text-variant); margin-top: 12rpx; display: block; }
.kpi-stack { display: flex; flex-direction: column; gap: 16rpx; }
.kpi-card { padding: 24rpx 28rpx; }
.balance-card { padding-bottom: 32rpx; }
.balance-sub { margin-top: 12rpx; font-size: 26rpx; }
.expense { color: var(--c-error); }
.income { color: #006d40; }
.quick-add-btn {
  margin-top: 16rpx;
  background: var(--c-primary);
  color: #fff;
  border-radius: 10rpx;
  padding: 12rpx 16rpx;
  font-size: 26rpx;
  font-weight: 600;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6rpx;
  width: 100%;
  box-sizing: border-box;
}
.quick-add-btn::before { content: '+'; font-size: 28rpx; line-height: 1; font-weight: 400; }
.empty { text-align: center; padding: 48rpx; color: var(--c-text-variant); font-size: 28rpx; }
.day-group { border-bottom: 1px solid var(--c-divider); }
.day-group:last-child { border-bottom: none; }
.day-header { display: flex; justify-content: space-between; padding: 12rpx 16rpx; background: var(--c-surface); }
.day-label { font-size: 24rpx; font-weight: 600; color: var(--c-text-variant); }
.day-net { font-size: 24rpx; font-weight: 600; color: var(--c-text-variant); }
.breakdown-row { display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; }
.breakdown-card { display: flex; flex-direction: column; gap: 16rpx; }
.empty-mini { text-align: center; padding: 32rpx; color: var(--c-text-variant); font-size: 24rpx; }
.cat-list { display: flex; flex-direction: column; gap: 20rpx; }
.cat-row { display: flex; flex-direction: column; gap: 6rpx; }
.cat-line { display: flex; justify-content: space-between; align-items: center; }
.cat-id { display: flex; align-items: center; gap: 10rpx; }
.cat-icon { width: 36rpx; height: 36rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.cat-icon-text { font-size: 22rpx; }
.cat-name { font-size: 26rpx; }
.cat-amt { font-size: 24rpx; color: var(--c-text-variant); }
.cat-bar-track { height: 6rpx; background: var(--c-surface); border-radius: 4rpx; overflow: hidden; }
.cat-bar-fill { height: 100%; border-radius: 4rpx; transition: width 0.3s ease; }
</style>
