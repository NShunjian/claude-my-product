<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { onShow } from '@dcloudio/uni-app'
import { useBookStore } from '@/stores/book'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { listAccounts, deleteAccount, archiveAccount, unarchiveAccount } from '@/api/accounts'
import { formatAmount } from '@/utils/finance'
import type { Account } from '@/api/accounts'
import AppHeader from '@/components/AppHeader.vue'
import { goBack } from '@/utils/back'

const book = useBookStore()
const auth = useAuthStore()
const toast = useToastStore()
const { t } = useLanguage()

/** 0=active only, 1=all(活跃+归档), 2=archived only。默认 active。 */
type FilterMode = 'active' | 'all' | 'archived'
const filterMode = ref<FilterMode>('active')

const accounts = ref<Account[]>([])
const loading = ref(false)
const error = ref<string | null>(null)

const visibleAccounts = computed(() => {
  if (filterMode.value === 'all') return accounts.value
  if (filterMode.value === 'archived') return accounts.value.filter(a => a.isArchived)
  return accounts.value.filter(a => !a.isArchived)
})

const totalBalance = computed(() =>
  // 资产净值按当前可见账户求和(active 模式 = 跟首页口径一致)
  visibleAccounts.value.reduce((s, a) => s + (a.balance ?? 0), 0)
)

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
    // 一次拉全量(active + archived),前端按 filterMode 切片。
    // 后端 includeArchived=true 才能拿到 archived=1,默认是 false。
    accounts.value = (await listAccounts({ bookId: book.current.uuid, includeArchived: true }))
      .filter((a): a is Account => !!a && !!a.id)
  } catch (e: any) {
    error.value = e?.message ?? ''
  } finally {
    loading.value = false
  }
}

function getTheme(acc: Account) {
  // ponytail: 背景色/前景色按 type 走 themeMap(视觉一致),emoji 优先用后端
  //          acc.icon(用户在 Flutter 端选的,跨端共享),fallback 到 type 默认。
  //          这样 Flutter / uniapp / H5 / 小程序 都从后端读同一字段,
  //          不会出现"同一账号两边图标不一样"的歧义。
  const t =
    acc.type === 'credit' ? themeMap.credit :
    acc.type === 'cash' ? themeMap.cash :
    acc.type === 'wallet' ? themeMap.wallet :
    themeMap.bank
  return {
    iconBg: t.iconBg,
    iconColor: t.iconColor,
    iconName: (acc.icon && acc.icon.trim()) || t.iconName,
  }
}

function subtitleOf(acc: Account): string {
  const map: Record<string, string> = { cash: '现金', debit: '借记卡', credit: '信用卡', wallet: '电子钱包', investment: '投资', other: '其他' }
  return map[acc.type] ?? '其他'
}

function confirmDelete(acc: Account) {
  uni.showActionSheet({
    itemList: acc.isArchived
      ? [t('accounts.unarchive'), t('common.delete')]
      : [t('accounts.archive'), t('common.delete')],
    success: async (res) => {
      if (acc.isArchived) {
        // 归档账户的菜单:0=取消归档, 1=删除
        if (res.tapIndex === 0) return confirmUnarchive(acc)
        if (res.tapIndex === 1) return doDelete(acc)
      } else {
        // 活跃账户的菜单:0=归档, 1=删除
        if (res.tapIndex === 0) return confirmArchive(acc)
        if (res.tapIndex === 1) return doDelete(acc)
      }
    },
  })
}

function confirmArchive(acc: Account) {
  uni.showModal({
    title: t('common.confirm'),
    content: t('accounts.archiveConfirm').replace('{name}', acc.name),
    success: async (res) => {
      if (!res.confirm) return
      try {
        await archiveAccount(acc.id)
        acc.isArchived = true
        toast.show(t('accounts.archiveSuccess'))
      } catch (e: any) {
        toast.show(e?.message ?? t('common.error'))
      }
    },
  })
}

function confirmUnarchive(acc: Account) {
  uni.showModal({
    title: t('common.confirm'),
    content: t('accounts.unarchiveConfirm').replace('{name}', acc.name),
    success: async (res) => {
      if (!res.confirm) return
      try {
        await unarchiveAccount(acc.id)
        acc.isArchived = false
        toast.show(t('accounts.unarchiveSuccess'))
      } catch (e: any) {
        toast.show(e?.message ?? t('common.error'))
      }
    },
  })
}

function doDelete(acc: Account) {
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
    <!-- ponytail: 账户页是 tab 内页不是 push 进来的,用户截图无返回箭头,back 去掉 -->
    <AppHeader :title="t('pageTitle.accounts')" />
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

        <!-- Filter chips -->
        <view class="filter-row">
          <view
            class="chip"
            :class="{ active: filterMode === 'active' }"
            @tap="filterMode = 'active'"
          >{{ t('accounts.filter.active') }}</view>
          <view
            class="chip"
            :class="{ active: filterMode === 'all' }"
            @tap="filterMode = 'all'"
          >{{ t('accounts.filter.all') }}</view>
          <view
            class="chip"
            :class="{ active: filterMode === 'archived' }"
            @tap="filterMode = 'archived'"
          >{{ t('accounts.filter.archivedOnly') }}</view>
        </view>

        <!-- Error -->
        <view v-if="error" class="error-box">{{ t('accounts.loadErrorPrefix') }}{{ error }}</view>

        <!-- Account list -->
        <view class="list">
          <view v-if="loading" class="empty">{{ t('accounts.loading') }}</view>
          <view v-else-if="visibleAccounts.length === 0" class="empty">{{ t('accounts.empty') }}</view>
          <view v-else class="grid">
            <view
              v-for="(acc, idx) in visibleAccounts"
              :key="acc?.id ?? `acc-${idx}`"
              class="acc-card"
              :class="{ archived: acc.isArchived }"
              @longpress="confirmDelete(acc)"
            >
              <view class="acc-top">
                <view class="acc-icon" :style="{ background: getTheme(acc).iconBg }">
                  <text class="icon-text" :style="{ color: getTheme(acc).iconColor }">{{ getTheme(acc).iconName }}</text>
                </view>
                <view class="acc-more" @tap="confirmDelete(acc)">
                  <text class="more-icon">⋮</text>
                </view>
              </view>
              <view class="acc-body">
                <view class="name-row">
                  <text class="acc-name">{{ acc.name }}</text>
                  <text v-if="acc.isArchived" class="archived-badge">{{ t('accounts.archivedBadge') }}</text>
                </view>
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
.filter-row { display: flex; gap: 12rpx; }
.chip { padding: 12rpx 24rpx; border-radius: 999rpx; background: var(--c-bg-card); border: 1px solid var(--c-divider); color: var(--c-text-variant); font-size: 24rpx; }
.chip.active { background: var(--c-primary); color: #fff; border-color: var(--c-primary); }
.error-box { background: #FFEBEE; color: #C62828; border-radius: 12rpx; padding: 20rpx; font-size: 26rpx; }
.empty { text-align: center; padding: 80rpx; color: var(--c-text-variant); font-size: 28rpx; }
.list { }
.grid { display: grid; grid-template-columns: 1fr 1fr; gap: 16rpx; }
.acc-card { background: var(--c-bg-card); border-radius: 16rpx; padding: 24rpx; display: flex; flex-direction: column; gap: 12rpx; border: 1px solid var(--c-divider); }
.acc-card.archived { opacity: 0.5; }
.acc-top { display: flex; justify-content: space-between; align-items: flex-start; }
.acc-icon { width: 80rpx; height: 80rpx; border-radius: 50%; display: flex; align-items: center; justify-content: center; }
.icon-text { font-size: 32rpx; }
.acc-more { padding: 8rpx; }
.more-icon { font-size: 32rpx; color: var(--c-text-variant); }
.acc-body { display: flex; flex-direction: column; gap: 4rpx; }
.name-row { display: flex; align-items: center; gap: 8rpx; flex-wrap: wrap; }
.acc-name { font-size: 28rpx; font-weight: 600; color: var(--c-text); }
.archived-badge { font-size: 20rpx; color: var(--c-text-variant); background: var(--c-divider); padding: 2rpx 10rpx; border-radius: 8rpx; }
.acc-sub { font-size: 22rpx; color: var(--c-text-variant); }
.acc-balance { font-size: 28rpx; font-weight: 700; color: var(--c-text); }
.acc-balance.expense { color: var(--c-error); }
</style>
