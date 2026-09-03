<script setup lang="ts">
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue'
import { useBookStore } from '@/stores/book'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { listAccounts } from '@/api/accounts'
import { listCategories } from '@/api/categories'
import { createRecord } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import type { RecordType } from '@/api/records'
import { todayLocal } from '@/utils/date'
import { formatAmount } from '@/utils/finance'
import { categoryPresentation } from '@/utils/category-presentation'
import { modalOpen } from '@/utils/modal-state'
import {
  setWindowBackgroundColor,
  restoreWindowBackgroundColor,
  captureWindowBackgroundColor,
} from '@/uni_modules/qa-window-bg/utssdk/index.uts'

/**
 * 快速记账弹框 —— 对齐 frontend-react-java RecordModal
 * Props: show (v-model:show), kind ('expense' | 'income'), 可选 categories/accounts 传入避免重复请求
 * Emits: update:show, saved
 */
const props = withDefaults(
  defineProps<{
    show: boolean
    kind?: 'expense' | 'income'
    categories?: Category[]
    accounts?: Account[]
  }>(),
  { kind: 'expense', categories: () => [], accounts: () => [] },
)
const emit = defineEmits<{
  (e: 'update:show', v: boolean): void
  (e: 'saved'): void
}>()

const book = useBookStore()
const toast = useToastStore()
const { t } = useLanguage()

const activeTab = ref<RecordType>(props.kind)
const note = ref('')
const categoryId = ref<string>('')
const accountId = ref<string>('')
const recordDate = ref(todayLocal())
const expression = ref('')
const showSuccess = ref(false)
const submitting = ref(false)
const errorMsg = ref<string | null>(null)

// 本地缓存:分类与账户(若父组件没传则自己拉)
const catsLocal = ref<Category[]>([])
const acctsLocal = ref<Account[]>([])
const catsActive = computed<Category[]>(() => props.categories.length ? props.categories : catsLocal.value)
const acctsActive = computed<Account[]>(() => props.accounts.length ? props.accounts : acctsLocal.value)
const visibleCats = computed(() =>
  catsActive.value
    .filter(c => c.type === activeTab.value)
    .map(c => {
      const pres = categoryPresentation(c)
      return { ...c, icon: pres.icon, color: pres.color }
    }),
)

function pickDefaultAccount(): string {
  const list = acctsActive.value
  const def = list.find(a => a.isDefault)
  return def?.id ?? list[0]?.id ?? ''
}

async function ensureData() {
  if (!book.current) return
  if (!props.categories.length && catsLocal.value.length === 0) {
    const [e, i] = await Promise.all([listCategories('expense'), listCategories('income')])
    catsLocal.value = [...e, ...i]
  }
  if (!props.accounts.length && acctsLocal.value.length === 0) {
    acctsLocal.value = await listAccounts({ bookId: book.current.uuid })
  }
}

function reset() {
  showSuccess.value = false
  submitting.value = false
  errorMsg.value = null
  expression.value = ''
  note.value = ''
  recordDate.value = todayLocal()
  activeTab.value = props.kind
}

// iOS app-plus WKWebView 默认 viewport-fit=auto,viewport = safe-area。
// position:fixed overlay 撑不到物理圆角区域,两侧露出 WKWebView 底层 bg(默认白)。
// 解决办法:modal 打开时直接调 WKWebView 原生 API 把外层 bg 也涂成 overlay 同色,
// 这样"圆角外"和"overlay 内"是同一种深色,视觉合一。
// 关闭时把 bg 还原到原始值(读取 .__originalBg 没读到就读 #fff 兜底)。
// 仅 APP-PLUS 生效 — H5 已有 viewport-fit=cover,MP 用原生 navigationStyle。
// ponytail: 备选改 pages.json per-page app-plus.webviewStyle.background,简单但页面
// 全程暗底;改成 JS 动态切只在 modal 开期间才暗,体验更好。
function getWV(): any | null {
  // #ifdef APP-PLUS
  try { return (plus as any)?.webview?.currentWebview?.() ?? null } catch { return null }
  // #endif
  return null
}
// iOS 上 WKWebView 在 UIWindow 圆角 mask 内,圆角外(两侧/顶部两个三角)是 mask 之外的
// UIWindow.backgroundColor —— JS-only 方案(WebView background / body bg / viewport-fit)
// 都染不到那块。uni_modules/qa-window-bg 是原生插件,open 时把 UIWindow.backgroundColor
// 涂成 overlay 同色,close 时还原(原色在首次打开时快照一次)。
function paintWVOpen() {
  const wv = getWV()
  // #ifdef APP-PLUS
  // 1. 隐藏 status bar + 让 WKWebView 顶到物理屏幕顶 —— 解决 iOS 上 sheet 距离顶部
  //    太大、navy 顶部区比 H5 高很多的问题。三端 sheet 视觉位置一致,只 iOS 需要 fullscreen。
  try {
    plus.navigator.setFullScreen && plus.navigator.setFullScreen(true)
    plus.navigator.setStatusBarBackground && plus.navigator.setStatusBarBackground('#141E3C')
  } catch { /* plus API 兼容 */ }
  // 2. 原生插件 UIWindow.backgroundColor = '#141E3C' —— 仅 HBuilderX 打包后才生效,
  //    覆盖 WKWebView 圆角 mask cutout 之外(物理圆角那条窄边)区域。
  try {
    captureWindowBackgroundColor()
    setWindowBackgroundColor('#141E3C')
  } catch { /* 原生插件未编译通过 —— 调试时常见,真机/打包后会好 */ }
  // #endif
  if (!wv) return
  try {
    if (!(wv as any).__qaOriginalBgCaptured) {
      let cur = '#ffffff'
      try {
        const gs = (typeof wv.getStyle === 'function') ? wv.getStyle() : wv.getStyle
        if (gs && typeof gs === 'object') {
          cur = (gs as any).background || (gs as any).backgroundColor || cur
        }
      } catch { /* keep fallback #ffffff */ }
      ;(wv as any).__qaOriginalBg = cur
      ;(wv as any).__qaOriginalBgCaptured = true
    }
    wv.setStyle({ background: '#141E3C' })
  } catch { /* 兜底:iOS 一些版本 setStyle 不支持这条 */ }
}
function paintWVClose() {
  const wv = getWV()
  // #ifdef APP-PLUS
  try {
    plus.navigator.setFullScreen && plus.navigator.setFullScreen(false)
    plus.navigator.setStatusBarBackground && plus.navigator.setStatusBarBackground('#FFFFFF')
  } catch { /* */ }
  try { restoreWindowBackgroundColor() } catch { /* */ }
  // #endif
  if (!wv) return
  try {
    const orig = (wv as any).__qaOriginalBg || '#ffffff'
    wv.setStyle({ background: orig })
  } catch { /* */ }
}

watch(
  () => props.show,
  (v) => {
    // 同步全局 modal 状态 — AppHeader watch modalOpen 在 modal 打开时把自己隐藏。
    // iOS app-plus WKWebView 里 overlay 偶尔压不住 sticky 元素,见 utils/modal-state。
    modalOpen.value = v
    if (v) {
      paintWVOpen()
      hideAppTabBar()
      reset()
      ensureData().then(() => {
        if (!categoryId.value) {
          categoryId.value = visibleCats.value[0]?.id ?? ''
        }
        if (!accountId.value) {
          accountId.value = pickDefaultAccount()
        }
      })
    } else {
      paintWVClose()
      showAppTabBar()
    }
  },
)

// 模态打开时隐藏底部 tabbar,关闭时恢复 — 否则 modal 遮罩背后能看到 tabbar(三个端都有问题)。
// H5:tabbar 是 uniapp 渲染的 .uni-tabbar 节点,通过 body 上的 .qa-open 类配合全局 CSS 隐藏。
// MP/app-plus:tabbar 是原生组件,uni.hideTabBar/showTabBar 单独控制。
// 用 ref 记状态防止快速 open/close 切换时漏调用 show。
const tabbarHidden = ref(false)
function hideAppTabBar() {
  if (tabbarHidden.value) return
  tabbarHidden.value = true
  // #ifdef H5
  document.body.classList.add('qa-open')
  // #endif
  // #ifdef MP-WEIXIN || APP-PLUS
  uni.hideTabBar({ animation: false })
  // #endif
}
function showAppTabBar() {
  if (!tabbarHidden.value) return
  tabbarHidden.value = false
  // #ifdef H5
  document.body.classList.remove('qa-open')
  // #endif
  // #ifdef MP-WEIXIN || APP-PLUS
  uni.showTabBar({ animation: false })
  // #endif
}

// 兜底:如果初次挂载时 show 就是 true(外部直接 v-if 进来),watch 不会触发,这里手动调一次
onMounted(() => {
  if (props.show) {
    hideAppTabBar()
    modalOpen.value = true
  }
})
// 组件被卸载时强制恢复 tabbar + 清掉全局 modal 状态,避免父级 navigateBack
// 导致 modal 还显示着就 destroy,AppHeader 一直停在 display:none 状态
onBeforeUnmount(() => {
  if (tabbarHidden.value) showAppTabBar()
  // 防止 modal 还开着时被卸载 → WKWebView 一直停在深色底
  if (props.show) paintWVClose()
  modalOpen.value = false
})

// 切 tab 时把分类重置到该类型的第一个
watch(activeTab, () => {
  categoryId.value = visibleCats.value[0]?.id ?? ''
  errorMsg.value = null
})

function close() {
  if (submitting.value) return
  emit('update:show', false)
}

function pressKey(key: string) {
  if (key === 'back') {
    expression.value = expression.value.slice(0, -1)
    return
  }
  if (key === 'op') {
    if (!expression.value) { expression.value = '0+'; return }
    const last = expression.value.slice(-1)
    if (last === '+' || last === '-') {
      expression.value = expression.value.slice(0, -1) + '+'
    } else {
      expression.value += '+'
    }
    return
  }
  if (key === '.') {
    const seg = expression.value.split(/[+\-]/).pop() ?? ''
    if (seg.includes('.')) return
    expression.value += '.'
    return
  }
  if (key === 'confirm') {
    submit()
    return
  }
  expression.value = (expression.value + key).slice(0, 12)
}

function computeAmount(): number {
  if (!expression.value) return 0
  if (!expression.value.includes('+')) {
    const n = parseFloat(expression.value)
    return Number.isFinite(n) ? n : 0
  }
  return expression.value.split('+').reduce((s, x) => s + (parseFloat(x) || 0), 0)
}

function displayAmount(): string {
  return formatAmount(computeAmount()).replace('¥', '')
}

async function submit() {
  const amount = computeAmount()
  if (amount <= 0) {
    errorMsg.value = '请输入金额'
    return
  }
  if (!categoryId.value) {
    errorMsg.value = t('recordExpense.categoryRequired')
    return
  }
  if (!accountId.value) {
    errorMsg.value = t('recordExpense.accountRequired')
    return
  }
  if (!book.current) {
    errorMsg.value = '未选择账本'
    return
  }
  errorMsg.value = null
  submitting.value = true
  try {
    await createRecord({
      type: activeTab.value as 'expense' | 'income',
      categoryId: categoryId.value,
      accountId: accountId.value,
      amount: Math.round(amount * 100) / 100,
      recordDate: recordDate.value,
      note: note.value.trim() || undefined,
      bookId: book.current.uuid,
    })
    showSuccess.value = true
    setTimeout(() => {
      emit('saved')
      close()
    }, 1200)
  } catch (e: any) {
    errorMsg.value = e?.message ?? '保存失败'
  } finally {
    submitting.value = false
  }
}

// 键盘:4 列 × 4 行
const KEYS: Array<{ label: string; value: string; span?: number; kind?: 'back' | 'op' | 'confirm' }> = [
  { label: '1', value: '1' },
  { label: '2', value: '2' },
  { label: '3', value: '3' },
  { label: '⌫', value: 'back', kind: 'back' },
  { label: '4', value: '4' },
  { label: '5', value: '5' },
  { label: '6', value: '6' },
  { label: '+', value: 'op', kind: 'op' },
  { label: '7', value: '7' },
  { label: '8', value: '8' },
  { label: '9', value: '9' },
  { label: '−', value: 'op', kind: 'op' },
  { label: '0', value: '0', span: 2 },
  { label: '.', value: '.' },
  { label: '✓', value: 'confirm', kind: 'confirm' },
]

function catTint(hex: string): string {
  // 把 #RRGGBB 转成 rgba(r,g,b,0.12) 简单粗暴
  const h = hex.replace('#', '')
  if (h.length !== 6) return hex + '22'
  const r = parseInt(h.slice(0, 2), 16)
  const g = parseInt(h.slice(2, 4), 16)
  const b = parseInt(h.slice(4, 6), 16)
  return `rgba(${r}, ${g}, ${b}, 0.14)`
}

const isExpense = computed(() => activeTab.value === 'expense')
const accentBg = computed(() => isExpense.value ? 'var(--c-primary)' : '#10b981')
</script>

<template>
  <!-- 整页遮罩 + 底部弹出 sheet -->
  <view v-if="show" class="qa-overlay" @tap.self="close">
    <view class="qa-sheet">
      <!-- 成功态 -->
      <view v-if="showSuccess" class="qa-success">
        <view class="qa-success-circle" :style="{ background: isExpense ? 'var(--c-primary-light)' : 'rgba(16,185,129,0.14)', color: accentBg }">
          <text class="qa-success-check">✓</text>
        </view>
        <text class="qa-success-text">
          {{ activeTab === 'expense' ? t('recordExpense.success') : t('recordIncome.success') }}
        </text>
      </view>

      <!-- 表单态 -->
      <template v-else>
        <!-- 顶部:关闭 + tab 切换 -->
        <view class="qa-head">
          <view class="qa-close" @tap="close">✕</view>
          <view class="qa-tabs">
            <view class="qa-tab" :class="{ active: activeTab === 'expense' }" @tap="activeTab = 'expense'">
              {{ t('recordModal.expense') }}
            </view>
            <view class="qa-tab" :class="{ active: activeTab === 'income' }" @tap="activeTab = 'income'">
              {{ t('recordModal.income') }}
            </view>
          </view>
          <view class="qa-head-spacer" />
        </view>

        <!-- 金额显示 -->
        <view class="qa-amount">
          <text class="qa-amount-hint">
            {{ activeTab === 'expense' ? t('recordExpense.amountPrompt') : t('recordIncome.amountPrompt') }}
          </text>
          <view class="qa-amount-row">
            <text class="qa-yen">¥</text>
            <text class="qa-amount-num">{{ displayAmount() }}</text>
            <text class="qa-cursor">|</text>
          </view>
        </view>

        <!-- 分类网格 -->
        <view class="qa-cats">
          <view v-if="visibleCats.length === 0" class="qa-empty">
            {{ t('recordModal.categoryLoading') }}
          </view>
          <view v-else class="qa-cats-grid">
            <view
              v-for="cat in visibleCats"
              :key="cat.id"
              class="qa-cat"
              @tap="categoryId = cat.id"
            >
              <view
                class="qa-cat-circle"
                :style="{
                  background: categoryId === cat.id ? cat.color : catTint(cat.color),
                  borderColor: categoryId === cat.id ? cat.color : 'transparent',
                }"
              >
                <text class="qa-cat-icon" :style="{ color: categoryId === cat.id ? '#fff' : cat.color }">
                  {{ cat.icon }}
                </text>
              </view>
              <text class="qa-cat-name" :style="{ color: categoryId === cat.id ? cat.color : 'var(--c-text)', fontWeight: categoryId === cat.id ? 600 : 400 }">
                {{ cat.name }}
              </text>
            </view>
          </view>
        </view>

        <!-- 账户 chips -->
        <view v-if="acctsActive.length > 0" class="qa-accounts">
          <text class="qa-acct-label">{{ t('recordModal.accountLabel') }}</text>
          <scroll-view scroll-x class="qa-acct-scroll">
            <view class="qa-acct-list">
              <view
                v-for="a in acctsActive"
                :key="a.id"
                class="qa-acct-chip"
                :class="{ active: a.id === accountId }"
                @tap="accountId = a.id"
              >
                <text class="qa-acct-chip-icon">💳</text>
                <text>{{ a.name }}</text>
              </view>
            </view>
          </scroll-view>
        </view>

        <!-- 日期 + 备注 -->
        <view class="qa-meta">
          <picker mode="date" :value="recordDate" @change="(e: any) => recordDate = e.detail.value">
            <view class="qa-date">
              <text>📅</text>
              <text>{{ recordDate }}</text>
            </view>
          </picker>
          <input
            v-model="note"
            :placeholder="t('recordModal.notePlaceholder')"
            class="qa-note"
            :maxlength="50"
          />
        </view>

        <!-- 错误 -->
        <view v-if="errorMsg" class="qa-error">{{ errorMsg }}</view>

        <!-- 数字键盘 -->
        <view class="qa-keypad">
          <view
            v-for="(k, i) in KEYS"
            :key="i"
            class="qa-key"
            :class="[k.kind === 'confirm' ? 'confirm' : '', k.kind === 'back' ? 'back' : '', k.kind === 'op' ? 'op' : '']"
            :style="k.span === 2 ? { gridColumn: 'span 2' } : {}"
            @tap="pressKey(k.value)"
          >
            <text v-if="k.kind === 'confirm' && submitting" class="qa-key-loading">⏳</text>
            <text v-else>{{ k.label }}</text>
          </view>
        </view>
      </template>
    </view>
  </view>
</template>

<style scoped>
.qa-overlay {
  position: fixed;
  inset: 0;
  z-index: 999;
  background: rgba(20, 30, 60, 0.78);
  backdrop-filter: blur(6px);
  -webkit-backdrop-filter: blur(6px);
  display: flex;
  flex-direction: column;
  justify-content: flex-end;
}
.qa-sheet {
  background: var(--c-bg-card);
  /* 四个角都圆,匹配 iPhone 物理圆角 —— 之前只有顶部圆,底部直角在 iPhone 圆角
     mask 区域里看上去像被切掉一角,keypad 两侧显得被遮挡。*/
  border-radius: 24rpx;
  border: 1px solid var(--c-divider);
  /* 底部留 1px 让圆角视觉完整(原本 border-bottom:none 是 bottom-sheet 风格,
     现在 sheet 撑到 viewport 底,要保留圆角边框让边角成型) */
  max-height: 92vh;
  display: flex;
  flex-direction: column;
  padding-bottom: env(safe-area-inset-bottom);
}
.qa-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 24rpx 32rpx;
  border-bottom: 1px solid var(--c-divider);
}
.qa-close {
  width: 56rpx;
  height: 56rpx;
  font-size: 32rpx;
  color: var(--c-text-variant);
  display: flex;
  align-items: center;
  justify-content: center;
}
.qa-head-spacer { width: 56rpx; }
.qa-tabs {
  display: flex;
  background: var(--c-surface);
  border-radius: 12rpx;
  padding: 4rpx;
  gap: 4rpx;
}
.qa-tab {
  padding: 10rpx 32rpx;
  border-radius: 8rpx;
  font-size: 26rpx;
  color: var(--c-text-variant);
}
.qa-tab.active {
  background: var(--c-bg-card);
  color: var(--c-primary);
  font-weight: 600;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}
.qa-amount {
  background: var(--c-bg);
  text-align: center;
  padding: 32rpx 24rpx 24rpx;
}
.qa-amount-hint {
  display: block;
  font-size: 22rpx;
  color: var(--c-text-variant);
  margin-bottom: 8rpx;
}
.qa-amount-row {
  display: flex;
  align-items: baseline;
  justify-content: center;
  gap: 6rpx;
}
.qa-yen {
  font-size: 32rpx;
  color: var(--c-text-variant);
}
.qa-amount-num {
  font-size: 72rpx;
  font-weight: 700;
  color: var(--c-text);
  border-bottom: 2rpx solid var(--c-primary);
  padding: 0 16rpx 6rpx;
  min-width: 200rpx;
  text-align: center;
  font-variant-numeric: tabular-nums;
}
.qa-cursor {
  font-size: 40rpx;
  color: var(--c-text);
  animation: qa-blink 1s steps(2, end) infinite;
}
@keyframes qa-blink { to { opacity: 0; } }
.qa-cats {
  padding: 24rpx 24rpx 16rpx;
  max-height: 40vh;
  overflow-y: auto;
}
.qa-empty {
  text-align: center;
  padding: 32rpx;
  color: var(--c-text-variant);
  font-size: 26rpx;
}
.qa-cats-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  row-gap: 24rpx;
  column-gap: 8rpx;
}
.qa-cat {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8rpx;
}
.qa-cat-circle {
  width: 88rpx;
  height: 88rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2rpx solid transparent;
  transition: transform 0.1s ease;
}
.qa-cat:active .qa-cat-circle { transform: scale(0.94); }
.qa-cat-icon {
  font-size: 40rpx;
  line-height: 1;
  font-weight: normal;
  font-style: normal;
}
.qa-cat-name {
  font-size: 22rpx;
  text-align: center;
}
.qa-accounts {
  display: flex;
  align-items: center;
  gap: 12rpx;
  padding: 8rpx 24rpx 16rpx;
}
.qa-acct-label {
  font-size: 22rpx;
  color: var(--c-text-variant);
  flex-shrink: 0;
}
.qa-acct-scroll {
  flex: 1;
  overflow-x: auto;
}
.qa-acct-list {
  display: flex;
  flex-wrap: nowrap;
  gap: 12rpx;
  width: max-content;
}
.qa-acct-chip {
  display: inline-flex;
  align-items: center;
  gap: 6rpx;
  padding: 8rpx 20rpx;
  border-radius: 28rpx;
  background: var(--c-surface);
  color: var(--c-text);
  font-size: 22rpx;
  white-space: nowrap;
  flex-shrink: 0;
}
.qa-acct-chip.active {
  background: var(--c-primary);
  color: #fff;
}
.qa-acct-chip-icon { font-size: 22rpx; }
.qa-meta {
  display: flex;
  gap: 16rpx;
  padding: 8rpx 24rpx 16rpx;
}
.qa-date {
  display: flex;
  align-items: center;
  gap: 6rpx;
  padding: 12rpx 20rpx;
  border-radius: 12rpx;
  background: var(--c-surface);
  font-size: 24rpx;
  color: var(--c-text);
  flex-shrink: 0;
}
.qa-note {
  flex: 1;
  padding: 12rpx 20rpx;
  border-radius: 12rpx;
  background: var(--c-surface);
  font-size: 24rpx;
  color: var(--c-text);
}
.qa-error {
  margin: 0 24rpx 12rpx;
  background: rgba(186, 26, 26, 0.12);
  color: var(--c-error);
  border-radius: 8rpx;
  padding: 12rpx 16rpx;
  font-size: 24rpx;
}
.qa-keypad {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  /* 上下左右四边的 padding 都取 env(safe-area-inset-*) + 32rpx,把 keypad 与屏幕
     边缘之间的"间隙"也当作容器一部分展示出来 —— 上下避开 home indicator / 状态栏,
     左右避开 iPhone 物理圆角/iPad 安全区。background = sheet bg,这些 padding 区
     都是 sheet 容器的视觉延伸。横屏时 safe-area-inset-left/right 非零能兜底。*/
  padding: 8rpx 32rpx calc(env(safe-area-inset-bottom, 0px) + 32rpx);
  padding-left: calc(env(safe-area-inset-left, 0px) + 32rpx);
  padding-right: calc(env(safe-area-inset-right, 0px) + 32rpx);
  gap: 8rpx;
  background: var(--c-bg-card);
  flex-shrink: 0;
}
.qa-key {
  height: 80rpx;
  border-radius: 12rpx;
  background: var(--c-surface);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 32rpx;
  font-weight: 500;
  color: var(--c-text);
}
.qa-key.back { background: var(--c-surface); color: var(--c-text-variant); }
.qa-key.op { background: var(--c-surface); }
.qa-key.confirm {
  background: v-bind(accentBg);
  color: #fff;
}
.qa-key:active { opacity: 0.7; }
.qa-key-loading { font-size: 28rpx; }
.qa-success {
  padding: 120rpx 24rpx 100rpx;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24rpx;
}
.qa-success-circle {
  width: 112rpx;
  height: 112rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
}
.qa-success-check {
  font-size: 56rpx;
  font-weight: 700;
}
.qa-success-text {
  font-size: 32rpx;
  font-weight: 600;
  color: var(--c-text);
}
</style>
