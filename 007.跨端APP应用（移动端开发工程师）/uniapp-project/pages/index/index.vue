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
import AppHeader from '@/components/AppHeader.vue'
import type { Record } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import { formatAmount } from '@/utils/finance'
import { formatLocalMonth, compareRecordDesc, formatMonthCN, formatRelativeDayLabel } from '@/utils/date'
import { categoryPresentation } from '@/utils/category-presentation'
import { setPendingMonth } from '@/utils/nav-intent'

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
const expenseByCat = computed(() => expenseCats.value.map(c => {
  const pres = categoryPresentation(c)
  return {
    cat: c,
    icon: pres.icon,
    color: pres.color,
    total: records.value.filter(r => r.type === 'expense' && r.categoryId === c.id).reduce((s, r) => s + r.amount, 0),
  }
}).sort((a, b) => b.total - a.total))
const incomeByCat = computed(() => incomeCats.value.map(c => {
  const pres = categoryPresentation(c)
  return {
    cat: c,
    icon: pres.icon,
    color: pres.color,
    total: records.value.filter(r => r.type === 'income' && r.categoryId === c.id).reduce((s, r) => s + r.amount, 0),
  }
}).sort((a, b) => b.total - a.total))

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

// "查看全部 →" 跳流水页:uni.switchTab 不支持 url query,改用一次性意图
function onViewAll() {
  setPendingMonth(month.value)
  uni.switchTab({ url: '/pages/transactions/index' })
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
// 顺带自愈:mp 冷启动 / 切换账号后,token 有但 book.current 还没就绪时,
// 这里主动 reload 一次,避免首次进首页 book.current === null 导致 load() 提前 return。
onShow(async () => {
  if (auth.token && !book.current) {
    try { await book.reload() } catch { /* 容忍,fallback 到 load 走原流程 */ }
  }
  load()
})
</script>

<template>
  <view class="page-root">
    <AppHeader :title="t('pageTitle.home')" />
    <scroll-view
      scroll-y
      class="scroll-area"
      :bounces="false"
    >
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
      <button class="quick-add-btn" @tap="onQuickAdd">
        <text class="quick-add-plus">+</text>
        <text>{{ t('home.quickAdd') }}</text>
      </button>
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
        <text class="view-all" @tap="onViewAll">{{ t('home.viewAll') }} →</text>
      </view>
      <view v-if="loading" class="empty">{{ t('home.loading') }}</view>
      <view v-else-if="records.length === 0" class="empty">{{ t('home.empty') }}</view>
      <view v-else>
        <view v-for="group in grouped" :key="group.date" class="day-group">
          <view class="day-header">
            <text class="day-label">{{ group.label }}</text>
            <text class="day-net">¥ {{ formatAmount(Math.abs(group.net)) }}</text>
          </view>
          <TransactionRow
            v-for="(r, idx) in group.recs"
            :key="r?.id ?? `row-${group.date}-${idx}`"
            :record="r"
            :category="findCat(r.categoryId)"
            :account="findAccount(r.accountId)"
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
            <view class="cat-row-top">
              <text class="cat-emoji" :style="{ color: row.color }">{{ row.icon }}</text>
              <text class="cat-name">{{ row.cat.name }}</text>
              <text class="cat-amt">¥{{ formatAmount(row.total) }}</text>
            </view>
            <view class="cat-bar-track">
              <view class="cat-bar-fill" :style="{
                width: (monthExpense > 0 ? (row.total / monthExpense) * 100 : 0) + '%',
                background: row.color,
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
            <view class="cat-row-top">
              <text class="cat-emoji" :style="{ color: row.color }">{{ row.icon }}</text>
              <text class="cat-name">{{ row.cat.name }}</text>
              <text class="cat-amt">¥{{ formatAmount(row.total) }}</text>
            </view>
            <view class="cat-bar-track">
              <view class="cat-bar-fill" :style="{
                width: (monthIncome > 0 ? (row.total / monthIncome) * 100 : 0) + '%',
                background: row.color,
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
    </scroll-view>
  </view>
</template>

<style scoped>
.page-root {
  /* flex column 容器:AppHeader 自然占顶部,scroll-view 用 flex:1 + height:0 占剩余;
     滚动只在 scroll-view 内发生,AppHeader 钉在视口顶部不跟滚 */
  display: flex;
  flex-direction: column;
  /* H5:扣掉 tabBar 高度,避免滚到最后一段内容被 fixed tabBar 盖住。
     uni-h5 运行时把 tabBar 高度写到 --tab-bar-height(非 tabBar 页 0px,tabBar 页 50px+safe-area)。
     MP 原生 tabBar 已让出空间,fallback 0px 等价 100vh,无副作用。 */
  height: calc(100vh - var(--tab-bar-height, 0px));
  background: var(--c-bg);
}
.scroll-area {
  /* flex:1 + height:0 是 mp scroll-view 的常见写法,确保 scroll-view 占满剩余高度。
     padding-top 故意设为 0:用户反馈导航栏下方不需要多余空带,内容要紧贴 nav 底边;
     各卡片的 margin-top 单独控制(assets-card / kpi-net / tab-bar)。 */
  flex: 1;
  height: 0;
  box-sizing: border-box;
  padding: 0 24rpx 24rpx;
  display: flex;
  flex-direction: column;
  gap: 20rpx;
  overscroll-behavior: none;
}
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  /* 距离导航栏底部 20rpx:用 margin-top 直接钉 .header 的位置(而不是 scroll-area 的 padding-top),
     避免 padding-top + AppHeader 内边距 + .assets-card margin-top + gap 叠加形成空块。 */
  margin-top: 20rpx;
}
.greeting { display: flex; flex-direction: column; gap: 4rpx; }
.title { font-size: 36rpx; font-weight: 700; }
.subtitle { font-size: 26rpx; color: var(--c-text-variant); }
.card { background: var(--c-bg-card); border: 1px solid var(--c-divider); border-radius: 16rpx; padding: 24rpx; }
.card-head { display: flex; justify-content: space-between; align-items: center; margin-bottom: 16rpx; }
.card-title { font-size: 30rpx; font-weight: 600; }
.view-all { font-size: 26rpx; color: var(--c-primary); }
.card-label { font-size: 26rpx; color: var(--c-text-variant); display: block; margin-bottom: 12rpx; }
.assets-card { position: relative; overflow: hidden; margin-top: 20rpx; }
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
  width: 100%;
  box-sizing: border-box;
}
.quick-add-plus { font-size: 28rpx; line-height: 1; font-weight: 400; margin-right: 6rpx; }
.empty { text-align: center; padding: 48rpx; color: var(--c-text-variant); font-size: 28rpx; }
.day-group { border-bottom: 1px solid var(--c-divider); }
.day-group:last-child { border-bottom: none; }
.day-header { display: flex; justify-content: space-between; padding: 12rpx 16rpx; background: var(--c-surface); }
.day-label { font-size: 24rpx; font-weight: 600; color: var(--c-text-variant); }
.day-net { font-size: 24rpx; font-weight: 600; color: var(--c-text-variant); }
.breakdown-row { display: flex; flex-direction: row; gap: 16rpx; }
.breakdown-row > .card { flex: 1; min-width: 0; }
.breakdown-card { display: flex; flex-direction: column; gap: 24rpx; }
.empty-mini { text-align: center; padding: 32rpx; color: var(--c-text-variant); font-size: 24rpx; }
.cat-list { display: flex; flex-direction: column; gap: 24rpx; }
.cat-row {
  display: flex;
  flex-direction: column;
  gap: 8rpx;
}
.cat-row-top {
  display: flex;
  flex-direction: row;
  align-items: center;
  gap: 12rpx;
}
.cat-emoji {
  font-size: 36rpx;
  line-height: 1;
  font-weight: normal;
  font-style: normal;
  flex-shrink: 0;
}
.cat-name {
  flex: 1;
  font-size: 26rpx;
  color: var(--c-text);
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  min-width: 0;
}
.cat-amt {
  flex-shrink: 0;
  font-size: 24rpx;
  color: var(--c-text-variant);
  font-variant-numeric: tabular-nums;
}
.cat-bar-track {
  height: 10rpx;
  background: #E8EEF7;
  border-radius: 6rpx;
  overflow: hidden;
}
.cat-bar-fill { height: 100%; border-radius: 6rpx; transition: width 0.3s ease; }
</style>
