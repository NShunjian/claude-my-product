<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useBookStore } from '@/stores/book'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { listRecords, deleteRecord } from '@/api/records'
import { listAccounts } from '@/api/accounts'
import { listCategories } from '@/api/categories'
import TransactionRow from '@/components/TransactionRow.vue'
import MonthPicker from '@/components/MonthPicker.vue'
import type { Record } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import { formatAmount } from '@/utils/finance'
import { formatLocalMonth, compareRecordDesc } from '@/utils/date'
import { consumePendingMonth } from '@/utils/nav-intent'

const book = useBookStore()
const auth = useAuthStore()
const toast = useToastStore()
const { t } = useLanguage()

// 日组标题:M月D日,星期X(对齐 React 流水页)
function formatDayHeaderCN(ymd: string): string {
  const d = new Date(ymd)
  if (Number.isNaN(d.getTime())) return ymd
  const weekday = d.toLocaleDateString('zh-CN', { weekday: 'long' })
  return `${d.getMonth() + 1}月${d.getDate()}日,${weekday}`
}

const filterMonth = ref(formatLocalMonth(new Date()))
const filterCategory = ref('all')
const filterAccount = ref('all')
const categoryIndex = ref(0)
const accountIndex = ref(0)

// 从首页"查看全部"带过来的月份(对齐 React:点击跳转时锁定到当时选择的月)
// 注意:uni.switchTab 不支持 url query,所以走一次性意图 nav-intent
// 注意:tabBar 页面是 keep-alive 的,只有首次挂载会触发 onLoad,之后切回只触发 onShow
// —— 所以消费意图放在 onShow,挂载时 watch(immediate) 已经会拉数据,这里再 load 一次兜底切回不刷新
onShow(() => {
  const m = consumePendingMonth()
  if (m && /^\d{4}-\d{2}$/.test(m) && m !== filterMonth.value) {
    filterMonth.value = m // watch([filterMonth, ...], load) 自动 load
  } else {
    load() // 切回 tab 时即便没有意图也要 refresh
  }
})

const records = ref<Record[]>([])
const accounts = ref<Account[]>([])
const cats = ref<Category[]>([])
const loading = ref(false)

const filteredRecords = computed(() => {
  return records.value.filter(r => {
    if (filterCategory.value !== 'all' && r.categoryId !== filterCategory.value) return false
    if (filterAccount.value !== 'all' && r.accountId !== filterAccount.value) return false
    return true
  }).sort(compareRecordDesc)
})

const monthIncome = computed(() => filteredRecords.value.filter(r => r.type === 'income').reduce((s, r) => s + r.amount, 0))
const monthExpense = computed(() => filteredRecords.value.filter(r => r.type === 'expense').reduce((s, r) => s + r.amount, 0))
const monthNet = computed(() => monthIncome.value - monthExpense.value)

const grouped = computed(() => {
  const map = new Map<string, Record[]>()
  for (const r of filteredRecords.value) {
    if (!r || !r.id) continue
    const arr = map.get(r.recordDate) ?? []
    arr.push(r)
    map.set(r.recordDate, arr)
  }
  return Array.from(map.entries()).map(([date, recs]) => ({
    date,
    recs,
    net: recs.reduce((s, r) => s + (r.type === 'income' ? r.amount : -r.amount), 0),
    label: formatDayHeaderCN(date),
  }))
})

const allCats = computed(() => cats.value)

function findAccount(id: string) { return accounts.value.find(a => a.id === id) }
function findCat(id: string | null) { return cats.value.find(c => c.id === id) }

async function load() {
  if (!auth.token || !book.current) return
  loading.value = true
  try {
    const [recs, accts, catsExp, catsInc] = await Promise.all([
      listRecords({ month: filterMonth.value, bookId: book.current.uuid }),
      listAccounts({ bookId: book.current.uuid }),
      listCategories('expense'),
      listCategories('income'),
    ])
    records.value = recs
    accounts.value = accts
    cats.value = [...catsExp, ...catsInc]
  } catch (e: any) {
    toast.show(t('transactions.loadErrorPrefix') + (e?.message ?? ''))
  } finally {
    loading.value = false
  }
}

async function remove(id: string) {
  uni.showModal({
    title: t('common.confirm'),
    content: t('transactions.deleteConfirm'),
    success: async (res) => {
      if (!res.confirm) return
      try {
        await deleteRecord(id)
        records.value = records.value.filter(r => r.id !== id)
        toast.show(t('common.delete') + ' OK')
      } catch (e: any) {
        toast.show(e?.message ?? t('common.error'))
      }
    },
  })
}

watch([filterMonth, () => book.current], load, { immediate: true })

function onCategoryChange(e: any) {
  const idx = Number(e.detail.value)
  categoryIndex.value = idx
  const list = [{ id: 'all', name: t('transactions.allCategories') }, ...allCats.value]
  filterCategory.value = list[idx]?.id ?? 'all'
}

function onAccountChange(e: any) {
  const idx = Number(e.detail.value)
  accountIndex.value = idx
  const list = [{ id: 'all', name: t('transactions.allAccounts') }, ...accounts.value]
  filterAccount.value = list[idx]?.id ?? 'all'
}
</script>

<template>
  <view class="page">
    <!-- Filter + Summary -->
    <view class="filter-row">
      <view class="filter-card">
        <text class="filter-title">{{ t('transactions.filterLabel') }}</text>
        <view class="filter-selects">
          <MonthPicker v-model="filterMonth" compact />
          <picker mode="selector" :range="[{ id: 'all', name: t('transactions.allCategories') }, ...allCats]" range-key="name" :value="categoryIndex" @change="onCategoryChange">
            <view class="select-box">{{ (([{ id: 'all', name: t('transactions.allCategories') }, ...allCats].find(c => c.id === filterCategory))?.name) || t('transactions.allCategories') }} ▼</view>
          </picker>
          <picker mode="selector" :range="[{ id: 'all', name: t('transactions.allAccounts') }, ...accounts]" range-key="name" :value="accountIndex" @change="onAccountChange">
            <view class="select-box">{{ (([{ id: 'all', name: t('transactions.allAccounts') }, ...accounts].find(a => a.id === filterAccount))?.name) || t('transactions.allAccounts') }} ▼</view>
          </picker>
        </view>
      </view>
      <view class="balance-card">
        <text class="balance-label">{{ t('transactions.monthBalance') }}</text>
        <text class="balance-amount">¥ {{ formatAmount(Math.abs(monthNet)) }}</text>
        <view class="balance-sub">
          <view class="balance-sub-item">
            <text class="sub-label">{{ t('transactions.income') }}</text>
            <text class="sub-value">+¥ {{ formatAmount(monthIncome) }}</text>
          </view>
          <view class="balance-sub-item right">
            <text class="sub-label">{{ t('transactions.expense') }}</text>
            <text class="sub-value">-¥ {{ formatAmount(monthExpense) }}</text>
          </view>
        </view>
      </view>
    </view>

    <!-- List -->
    <view class="list-card">
      <view v-if="loading" class="empty">{{ t('transactions.loading') }}</view>
      <view v-else-if="filteredRecords.length === 0" class="empty">{{ t('transactions.empty') }}</view>
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
            :account="findAccount(r.accountId)"
            @tap="remove(r.id)"
          />
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.filter-row { display: flex; flex-direction: column; gap: 16rpx; }
.filter-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; border: 1px solid var(--c-divider); }
.filter-title { font-size: 28rpx; font-weight: 600; margin-bottom: 16rpx; display: block; }
.filter-selects { display: flex; flex-wrap: nowrap; gap: 12rpx; align-items: stretch; }
.filter-selects > picker,
.filter-selects > .mp { flex: 1; min-width: 0; }
.select-box {
  width: 100%;
  border: 2rpx solid var(--c-divider);
  border-radius: 12rpx;
  padding: 16rpx 20rpx;
  font-size: 26rpx;
  background: var(--c-bg-card);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  box-sizing: border-box;
  display: block;
}
.balance-card { background: var(--c-primary); border-radius: 16rpx; padding: 32rpx; color: #fff; display: flex; flex-direction: column; gap: 16rpx; }
.balance-label { font-size: 26rpx; opacity: 0.9; display: block; }
.balance-amount { font-size: 56rpx; font-weight: 700; display: block; line-height: 1.1; font-variant-numeric: tabular-nums; }
.balance-sub { display: flex; justify-content: space-between; margin-top: 12rpx; }
.balance-sub-item { display: flex; flex-direction: column; gap: 6rpx; }
.balance-sub-item.right { align-items: flex-end; }
.sub-label { font-size: 24rpx; opacity: 0.9; }
.sub-value { font-size: 30rpx; font-weight: 600; font-variant-numeric: tabular-nums; }
.list-card { background: var(--c-bg-card); border-radius: 16rpx; overflow: hidden; border: 1px solid var(--c-divider); }
/* 流水行左 padding 在首页与流水页不同:首页 .card 已自带 padding(0 即可),流水页 .list-card 无 padding(需补 24rpx 与 day-header 文字对齐) */
.list-card :deep(.row) { padding-left: 24rpx; }
.empty { text-align: center; padding: 80rpx; color: var(--c-text-variant); font-size: 28rpx; }
.day-group { border-bottom: 1px solid var(--c-divider); }
.day-group:last-child { border-bottom: none; }
.day-header { display: flex; justify-content: space-between; align-items: center; padding: 16rpx 24rpx; background: var(--c-surface); }
.day-label { font-size: 26rpx; font-weight: 600; color: var(--c-text-variant); }
.day-net { font-size: 26rpx; font-weight: 600; color: var(--c-text-variant); font-variant-numeric: tabular-nums; }
.income { color: #006d40; }
.expense { color: var(--c-error); }
</style>
