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
import type { Record } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import { formatAmount } from '@/utils/finance'
import { formatLocalMonth, compareRecordDesc } from '@/utils/date'

const book = useBookStore()
const auth = useAuthStore()
const toast = useToastStore()
const { t } = useLanguage()

function recentMonths(): string[] {
  const out: string[] = []
  const now = new Date()
  for (let i = 0; i < 6; i++) {
    out.push(formatLocalMonth(new Date(now.getFullYear(), now.getMonth() - i, 1)))
  }
  return out
}

function formatMonthLabel(m: string): string {
  const [y, mo] = m.split('-')
  return `${y}年 ${parseInt(mo, 10)}月`
}

const filterMonth = ref(formatLocalMonth(new Date()))
const filterCategory = ref('all')
const filterAccount = ref('all')
const categoryIndex = ref(0)
const accountIndex = ref(0)

const records = ref<Record[]>([])
const accounts = ref<Account[]>([])
const cats = ref<Category[]>([])
const loading = ref(false)

const months = recentMonths()

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
onShow(load)

function onMonthChange(e: any) {
  filterMonth.value = months[Number(e.detail.value)]
}

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
          <picker mode="selector" :range="months" :value="months.indexOf(filterMonth)" :range-text="months.map(formatMonthLabel)" @change="onMonthChange">
            <view class="select-box">{{ formatMonthLabel(filterMonth) }} ▼</view>
          </picker>
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
        <text class="balance-amount">
          {{ monthNet >= 0 ? '+' : '-' }}¥ {{ formatAmount(Math.abs(monthNet)) }}
        </text>
        <view class="balance-sub">
          <text>{{ t('transactions.income') }}: +¥ {{ formatAmount(monthIncome) }}</text>
          <text>{{ t('transactions.expense') }}: -¥ {{ formatAmount(monthExpense) }}</text>
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
.filter-selects { display: flex; flex-wrap: wrap; gap: 12rpx; }
.select-box { border: 1px solid var(--c-divider); border-radius: 8rpx; padding: 12rpx 16rpx; font-size: 26rpx; background: var(--c-bg); }
.balance-card { background: var(--c-primary); border-radius: 16rpx; padding: 24rpx; color: #fff; }
.balance-label { font-size: 24rpx; opacity: 0.8; display: block; margin-bottom: 8rpx; }
.balance-amount { font-size: 40rpx; font-weight: 700; display: block; }
.balance-sub { display: flex; justify-content: space-between; margin-top: 12rpx; font-size: 24rpx; opacity: 0.9; }
.list-card { background: var(--c-bg-card); border-radius: 16rpx; overflow: hidden; border: 1px solid var(--c-divider); }
.empty { text-align: center; padding: 80rpx; color: var(--c-text-variant); font-size: 28rpx; }
.day-group { border-bottom: 1px solid var(--c-divider); }
.day-group:last-child { border-bottom: none; }
.day-header { display: flex; justify-content: space-between; padding: 16rpx 24rpx; background: var(--c-surface); }
.day-label { font-size: 26rpx; font-weight: 600; color: var(--c-text-variant); }
.day-net { font-size: 26rpx; font-weight: 600; color: var(--c-text-variant); }
.income { color: #006d40; }
.expense { color: var(--c-error); }
</style>
