<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { useBookStore } from '@/stores/book'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { useQuickAddStore } from '@/stores/quick-add'
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
 * 快速记账弹框 —— 对齐 frontend-react-java RecordModal。
 * 状态来源:useQuickAddStore(show / kind / savedAt),而不是 props/emit。
 * 渲染位置:Vue3 <Teleport to="body"> 把 modal 节点搬到 body 末尾,
 * 脱离 page-root position:fixed + bottom:var(--tab-bar-height) 的裁切。
 * iOS Safari 上 qa-sheet bottom:0 真正钉到 viewport 底,不再漏底部 navy。
 * saved 回调:不再 emit,改成 store.notifySaved() 把 savedAt++,调用方 watch 它。
 */
const store = useQuickAddStore()

// iOS APP-PLUS 单独判断 —— Vue 3 <Teleport> 在 iOS Safari + WKWebView + uniapp
// 编译产物下,即使 :disabled=true 仍会被 Vue patch,触发 nextSibling / _vei /
// setAttribute null pointer 崩,导致 modal 永远不弹。所以 iOS 必须完全跳过
// Teleport 节点,在 template 里走单独的"直接渲染"分支。
// H5 Chrome / Android APP-PLUS 不受影响(isIOS=false 走 Teleport);mp-weixin
// 这行被 #ifdef strip 完全看不到,零干扰。
// #ifdef H5 || APP-PLUS
const isIOS = (() => {
  try {
    const sys = (uni.getSystemInfoSync?.() ?? {}) as { system?: string }
    return /iOS|iPad/i.test(sys.system ?? '')
  } catch { return false }
})()
// #endif

const book = useBookStore()
const toast = useToastStore()
const { t } = useLanguage()

const activeTab = ref<RecordType>('expense')
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
const catsActive = computed<Category[]>(() => catsLocal.value)
const acctsActive = computed<Account[]>(() => acctsLocal.value)
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
  if (catsLocal.value.length === 0) {
    const [e, i] = await Promise.all([listCategories('expense'), listCategories('income')])
    catsLocal.value = [...e, ...i]
  }
  if (acctsLocal.value.length === 0) {
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
  activeTab.value = store.kind
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

// 模态打开时隐藏底部 tabbar,关闭时恢复 — 否则 modal 遮罩背后能看到 tabbar(三个端都有问题)。
// H5:tabbar 是 uniapp 渲染的 .uni-tabbar 节点,通过 body 上的 .qa-open 类配合全局 CSS 隐藏。
// MP/app-plus:tabbar 是原生组件,uni.hideTabBar/showTabBar 单独控制。
// 用 ref 记状态防止快速 open/close 切换时漏调用 show。
// 注意:tabbarHidden 必须先于下方 watch 声明,否则 watch immediate:true 在第一次同步回调
// (store.show === false → showAppTabBar)时访问 tabbarHidden,触发 const TDZ 报错
// "Cannot access 'tabbarHidden' before initialization"。
const tabbarHidden = ref(false)
function hideAppTabBar() {
  if (tabbarHidden.value) return
  tabbarHidden.value = true
  // #ifdef H5
  document.body.classList.add('qa-open')
  // 同时挂到 html —— iOS Safari + viewport-fit=cover 下,html 的 bg 才是真正
  // 撑到物理屏幕边缘(包括圆角那条窄边)的层,body 在 html 内可能因 overflow:
  // hidden / height:100% 被裁掉最外圈。App.vue 里 html.qa-open 也定义 navy bg。
  document.documentElement.classList.add('qa-open')
  // iOS Safari / WKWebView 在 Dynamic Island 那条窄带下用浏览器自己的页面背景
  // 渲染(不是 WebView 内容),body bg 染不到。theme-color 是 Apple 官方控制
  // 那条带子底色的口子 —— 打开 modal 时切 navy,关闭切回。动态改 meta 而不是
  // 写死,避免影响其它页面。
  try {
    const meta = document.querySelector('meta[name="theme-color"]') as HTMLMetaElement | null
    if (meta) meta.setAttribute('content', '#141E3C')
  } catch { /* meta 不存在或 DOM 还没好,跳过 */ }
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
  document.documentElement.classList.remove('qa-open')
  try {
    const meta = document.querySelector('meta[name="theme-color"]') as HTMLMetaElement | null
    if (meta) meta.setAttribute('content', '#FFFFFF')
  } catch { /* */ }
  // #endif
  // #ifdef MP-WEIXIN || APP-PLUS
  uni.showTabBar({ animation: false })
  // #endif
}

watch(
  () => store.show,
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
  // immediate:true —— modal 是 v-if 挂载,挂上来时 store.show 已经是 true,
  // 监听不会自己 fire,会导致 reset / ensureData / hideAppTabBar 全不跑,
  // 弹框出来但里面没数据 + tabbar 还在。打开首次回调即可。
  { immediate: true },
)

// 兜底:如果初次挂载时 show 就是 true,watch immediate:true 已经会跑,
// 不需要 onMounted。保留 watch 单一入口,避免双跑。

// 切 tab 时把分类重置到该类型的第一个
watch(activeTab, () => {
  categoryId.value = visibleCats.value[0]?.id ?? ''
  errorMsg.value = null
})

function close() {
  if (submitting.value) return
  store.close()
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
      store.notifySaved()
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
  <!-- Teleport 把 modal 节点搬到 body 末尾 —— 在 page 树里写
       <QuickAddModal /> 但实际渲染位置是 <body>,彻底脱离 page-root
       position:fixed + bottom:var(--tab-bar-height) 的裁切。iOS Safari
       上 qa-sheet bottom:0 真正钉到 viewport 底,不再漏底部 navy。
       条件编译:mp-weixin 不支持 Teleport(WXML 无此概念,编译报
       "not supported: Teleport");APP-PLUS 用 webview 跟 H5 一样支持。
       mp 直接走 <view> 渲染,虽然仍被 page-root 容器裁 —— 之后如需 mp
       也脱离裁切,再单独处理(可能需要写原生插件)。 -->
  <!-- 分支 1:iOS APP-PLUS 直接渲染 —— Vue 3 <Teleport> 在 iOS Safari + WKWebView +
       uniapp 编译产物下被 patch 时会触发 nextSibling/_vei/setAttribute/parentNode
       null 崩。iOS 必须完全跳过 Teleport 节点,直挂 + position:fixed 撑到
       viewport(与 mp-weixin 一致)。这里用独立 v-if="isIOS && store.show",
       跟下方 Teleport 互不构成 v-else 关系,避免 Vue Fragment 切占位节点
       在 iOS 上 parentNode 为 null 的二次崩。
       H5 Chrome 端 isIOS=false → 这条 v-if 短路、不渲染;mp-weixin 端
       #ifdef H5 || APP-PLUS 把整段 strip 掉,零影响。-->
  <!-- #ifdef H5 || APP-PLUS -->
  <view v-if="isIOS && store.show" class="qa-overlay" @tap="close">
    <view class="qa-sheet" @tap.stop>
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
  <!-- #endif -->

  <!-- 分支 2:H5 Chrome / 非 iOS APP-PLUS —— Teleport 把 modal 节点搬到 body 末尾。
       v-if="!isIOS" 独立判断(不与分支 1 构成 v-else),避免 Vue Fragment 占位节点
       在 iOS 上 parentNode 为 null 二次崩。mp-weixin 端 #ifdef 把 Teleport 标签
       strip 掉,只剩 <view v-if="store.show">...</view> 直挂逻辑,行为不变。-->
  <!-- #ifdef H5 || APP-PLUS -->
  <Teleport v-if="!isIOS" to="body">
  <!-- #endif -->
    <!-- 关闭逻辑:overlay 直接 @tap=close,sheet @tap.stop 拦住冒泡。
         原版用 @tap.self="close" 在 mp-weixin 不可靠(self 修饰符在 mp 偶尔
         不生效,点 sheet 内部也会冒到 overlay 触发关闭) → sheet 上手动
         .stop 阻止冒泡最稳。H5 / APP-PLUS / mp-weixin 三端行为一致。-->
    <view v-if="store.show" class="qa-overlay" @tap="close">
      <view class="qa-sheet" @tap.stop>
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
  <!-- #ifdef H5 || APP-PLUS -->
  </Teleport>
  <!-- #endif -->
</template>

<style scoped>
.qa-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 999;
  /* 顶部 navy 实心填充 —— 把页面背景完全遮住,modal 上半部只看到 navy 和 sheet。
     Teleport to body 后 overlay 直接挂在 body 下,position:fixed 相对 viewport。*/
  background: #141E3C;
}
/* sheet absolute bottom:0,containing block = qa-overlay = viewport(Teleport 后
   overlay 是 body 直接子级,fixed 相对 body) → iOS Safari 上 sheet 底 = 屏幕底,
   不再漏底部 navy。内部 UI 全部不动。*/
.qa-sheet {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--c-bg-card);
  /* 直角矩形贴在 navy backdrop 上 —— 顶部跟 navy 实色无缝衔接,不出现圆角漏 navy
     的小三角;底部 0 边距直达屏幕底,直角也不会被 iPhone 圆角 mask 截掉。
     !important 防 uniapp H5 编译/全局样式继承把圆角再补回来。
     仅顶部两角圆 —— 顶部衔接 navy backdrop,圆角让 sheet 视觉像一张卡片浮起;
     底部抵屏幕边,直角更干净。*/
  border-radius: 24rpx 24rpx 0 0 !important;
  border: 1px solid var(--c-divider);
  max-height: 96vh;
  max-height: 100dvh;
  display: flex;
  flex-direction: column;
  overflow-y: auto;
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
  /* 直角 —— 顶部 sheet 已取消圆角,tabs 容器跟 sheet 边沿平直衔接,
     不在 navy backdrop 旁露出小圆角。*/
  border-radius: 0;
  padding: 4rpx;
  gap: 4rpx;
}
.qa-tab {
  padding: 10rpx 32rpx;
  border-radius: 0;
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
  /* padding 32→16,跟 keypad 行高 80→72 一起,把 sheet 总高压到 96vh 内,
     多数情况下 keypad 不再溢出、不用滚动。*/
  padding: 16rpx 24rpx 16rpx;
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
  /* 72→56rpx,跟 amount padding 缩、keypad 行高缩配合,让 sheet 总高能在 96vh 内
     不溢出 keypad。字号仍读得清、视觉重心不变。*/
  font-size: 56rpx;
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
  /* sticky 钉在 sheet 视口底 —— sheet 内容总高还是超过 96vh(尤其多分类时),
     之前 keypad 排在 sheet 末尾,溢出就被 overflow-y:auto 截掉,看起来"键盘被挡"。
     钉在底后,sheet 内部可滚看 head/amount/cats,keypad 永远在底,不再被吃。
     z-index 让它滚到内容上面时压在前景。*/
  position: sticky;
  bottom: 0;
  z-index: 1;
}
.qa-key {
  /* 80→72rpx,4 行省 32rpx = ~10pt,跟 amount 缩、sheet 96vh 一起凑合,多数情况
     keypad 4 行都进 sheet 内、不用滚动。视觉上比 80 略小但还点得动。*/
  height: 72rpx;
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
