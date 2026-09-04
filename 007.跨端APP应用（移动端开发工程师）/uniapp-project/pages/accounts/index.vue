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

// iconName 之前是 Material Symbols ligature 字符串(chat_bubble / credit_card 等),
// 没加载字体时会渲染成 "credit_card" 这种英文乱码 —— settings 自定义分类踩过同样的坑。
// 改成跨平台可用的 emoji 字(各家系统 / 小程序 / iOS 都自带,不存在白字)。
const themeMap: Record<string, { iconBg: string; iconColor: string; iconName: string }> = {
  wechat: { iconBg: '#E5F5E9', iconColor: '#09B83E', iconName: '💬' },
  alipay: { iconBg: '#E3F2FD', iconColor: '#1677FF', iconName: '💰' },
  bank:   { iconBg: '#e5eeff', iconColor: '#005394', iconName: '🏦' },
  credit: { iconBg: 'rgb(167 8 25 / 0.12)', iconColor: '#ba1a1a', iconName: '💳' },
  cash:   { iconBg: '#dce9ff', iconColor: '#8B6E4E', iconName: '💵' },
  wallet: { iconBg: '#E5F5E9', iconColor: '#09B83E', iconName: '👛' },
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
  <view class="page-root tabbar-page">
    <AppHeader :title="t('pageTitle.accounts')" back @back="goBack" />
    <scroll-view scroll-y class="scroll-area" :bounces="false">
      <view class="page">
        <!-- Net assets + add -->
        <view class="net-card">
          <view class="net-label">{{ t('accounts.netAssets') }}</view>
          <text class="net-amount" :class="totalBalance < 0 ? 'expense' : ''">¥ {{ formatAmount(totalBalance, false) }}</text>
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
              <!-- 真实余额:formatAmount(toLocaleString) 会自动给负数加 '-',不再 Math.abs -->
              <text class="acc-balance" :class="acc.balance < 0 ? 'expense' : ''">
                ¥ {{ formatAmount(acc.balance, false) }}
              </text>
            </view>
          </view>
        </view>
      </view>
    </scroll-view>
  </view>
</template>

<style scoped>
/* 跨端可滚动外壳:H5 / iOS 需要 scroll-view 才能上下滑动,微信小程序原生就能滚所以包了也无害。
   page-root 用 calc(100vh - --tab-bar-height) 占满剩余视口,scroll-area flex:1 + height:0 拿到剩余高度。 */
.page-root {
  display: flex;
  flex-direction: column;
  height: calc(100vh - var(--tab-bar-height, 0px));
  background: var(--c-bg);
}
.scroll-area {
  flex: 1;
  height: 0;
  box-sizing: border-box;
}
.page { padding: 24rpx; display: flex; flex-direction: column; gap: 20rpx; }
.net-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 28rpx; display: flex; flex-direction: column; gap: 8rpx; border: 1px solid var(--c-divider); }
.net-label { font-size: 24rpx; color: var(--c-text-variant); text-transform: uppercase; letter-spacing: 1px; }
.net-amount { font-size: 48rpx; font-weight: 700; color: var(--c-text); }
.net-amount.expense { color: var(--c-error); }
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
