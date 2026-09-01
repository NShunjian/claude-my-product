<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useBookStore } from '@/stores/book'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { listAccounts, deleteAccount } from '@/api/accounts'
import { formatAmount } from '@/utils/finance'
import type { Account } from '@/api/accounts'
import AppHeader from '@/components/AppHeader.vue'
import { goBack } from '@/utils/back'

const book = useBookStore()
const auth = useAuthStore()
const toast = useToastStore()
const { t } = useLanguage()

const accounts = ref<Account[]>([])
const loading = ref(false)
const error = ref<string | null>(null)

const totalBalance = computed(() => accounts.value.reduce((s, a) => s + (a.balance ?? 0), 0))

const themeMap: Record<string, { iconBg: string; iconColor: string; iconName: string }> = {
  wechat: { iconBg: '#E5F5E9', iconColor: '#09B83E', iconName: 'chat_bubble' },
  alipay: { iconBg: '#E3F2FD', iconColor: '#1677FF', iconName: 'payments' },
  bank:   { iconBg: '#e5eeff', iconColor: '#005394', iconName: 'account_balance' },
  credit: { iconBg: 'rgb(167 8 25 / 0.12)', iconColor: '#ba1a1a', iconName: 'credit_card' },
  cash:   { iconBg: '#dce9ff', iconColor: '#8B6E4E', iconName: 'local_atm' },
  wallet: { iconBg: '#E5F5E9', iconColor: '#09B83E', iconName: 'account_balance_wallet' },
}

async function load() {
  if (!auth.token || !book.current) return
  loading.value = true
  error.value = null
  try {
    accounts.value = (await listAccounts({ bookId: book.current.uuid })).filter((a): a is Account => !!a && !!a.id)
  } catch (e: any) {
    error.value = e?.message ?? ''
  } finally {
    loading.value = false
  }
}

function getTheme(acc: Account) {
  if (acc.type === 'credit') return themeMap.credit
  if (acc.type === 'cash') return themeMap.cash
  if (acc.type === 'wallet') return themeMap.wallet
  if (acc.type === 'debit') return themeMap.bank
  return themeMap.bank
}

function subtitleOf(acc: Account): string {
  const map: Record<string, string> = { cash: '现金', debit: '借记卡', credit: '信用卡', wallet: '电子钱包', investment: '投资', other: '其他' }
  return map[acc.type] ?? '其他'
}

function confirmDelete(acc: Account) {
  uni.showModal({
    title: t('common.confirm'),
    content: t('accounts.deleteConfirm'),
    success: async (res) => {
      if (!res.confirm) return
      try {
        await deleteAccount(acc.id)
        accounts.value = accounts.value.filter(a => a.id !== acc.id)
        toast.show(t('common.delete') + ' OK')
      } catch (e: any) {
        toast.show(e?.message ?? t('common.error'))
      }
    },
  })
}

watch([() => auth.token, () => book.current], () => { load() }, { immediate: true })
onShow(load)
</script>

<template>
  <AppHeader :title="t('pageTitle.accounts')" back @back="goBack" />
  <view class="page">
    <!-- Net assets + add -->
    <view class="net-card">
      <view class="net-label">{{ t('accounts.netAssets') }}</view>
      <text class="net-amount">¥ {{ formatAmount(totalBalance, false) }}</text>
      <view class="add-btn" @tap="uni.navigateTo({ url: '/pages/accounts/new' })">
        <text class="add-icon">+</text>
        <text>{{ t('accounts.addCta') }}</text>
      </view>
    </view>

    <!-- Error -->
    <view v-if="error" class="error-box">{{ t('accounts.loadErrorPrefix') }}{{ error }}</view>

    <!-- Account list -->
    <view class="list">
      <view v-if="loading" class="empty">{{ t('accounts.loading') }}</view>
      <view v-else-if="accounts.length === 0" class="empty">{{ t('accounts.empty') }}</view>
      <view v-else class="grid">
        <view v-for="(acc, idx) in accounts" :key="acc?.id ?? `acc-${idx}`" class="acc-card" @longpress="confirmDelete(acc)">
          <view class="acc-top">
            <view class="acc-icon" :style="{ background: getTheme(acc).iconBg }">
              <text class="icon-text" :style="{ color: getTheme(acc).iconColor }">{{ getTheme(acc).iconName }}</text>
            </view>
            <view class="acc-more" @tap="confirmDelete(acc)">
              <text class="more-icon">⋮</text>
            </view>
          </view>
          <view class="acc-body">
            <text class="acc-name">{{ acc.name }}</text>
            <text class="acc-sub">{{ subtitleOf(acc) }}</text>
          </view>
          <text class="acc-balance" :class="acc.type === 'credit' ? 'expense' : ''">
            {{ acc.type === 'credit' ? '-' : '' }}¥ {{ formatAmount(Math.abs(acc.balance), false) }}
          </text>
        </view>
      </view>
    </view>
  </view>
</template>

<style scoped>
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.net-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 28rpx; display: flex; flex-direction: column; gap: 8rpx; border: 1px solid var(--c-divider); }
.net-label { font-size: 24rpx; color: var(--c-text-variant); text-transform: uppercase; letter-spacing: 1px; }
.net-amount { font-size: 48rpx; font-weight: 700; color: var(--c-text); }
.add-btn { display: flex; align-items: center; gap: 8rpx; margin-top: 12rpx; background: var(--c-primary); color: #fff; border-radius: 12rpx; padding: 16rpx 24rpx; font-size: 28rpx; font-weight: 600; }
.add-icon { font-size: 32rpx; }
.error-box { background: #FFEBEE; color: #C62828; border-radius: 12rpx; padding: 20rpx; font-size: 26rpx; }
.empty { text-align: center; padding: 80rpx; color: var(--c-text-variant); font-size: 28rpx; }
.list { }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; }
.acc-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; display: flex; flex-direction: column; gap: 12rpx; border: 1px solid var(--c-divider); }
.acc-top { display: flex; justify-content: space-between; align-items: flex-start; }
.acc-icon { width: 80rpx; height: 80rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.icon-text { font-size: 32rpx; }
.acc-more { padding: 8rpx; }
.more-icon { font-size: 32rpx; color: var(--c-text-variant); }
.acc-body { display: flex; flex-direction: column; gap: 4rpx; }
.acc-name { font-size: 28rpx; font-weight: 600; color: var(--c-text); }
.acc-sub { font-size: 22rpx; color: var(--c-text-variant); }
.acc-balance { font-size: 28rpx; font-weight: 700; color: var(--c-text); }
.acc-balance.expense { color: var(--c-error); }
</style>
