<script setup lang="ts">
import { onLaunch } from '@dcloudio/uni-app'
import { useAuthStore } from '@/stores/auth'
import { useBookStore } from '@/stores/book'
import { useThemeStore } from '@/stores/theme'
import { useLanguageStore } from '@/stores/language'
import { runSilent } from '@/api/http'
import ToastHost from '@/components/Toast.vue'

const auth = useAuthStore()
const book = useBookStore()
const theme = useThemeStore()
const lang  = useLanguageStore()

// #ifdef H5
/**
 * H5:5 个 tabBar 页用 height:calc(100vh - var(--tab-bar-height)) 算出剩余视口高度,
 * 但 uniapp 不会自动写这个变量,fallback 0px → 页面铺满 100vh → 最后一段内容被 fixed tabBar 盖住。
 *
 * 关键:uniapp H5 不同版本 / 自定义 tabbar / uniappx 编译产物用的类名不一致
 * (.uni-tabbar / .uni-tabbar-bottom / [class*=tabbar] ...),
 * 直接 getBoundingClientRect 拿到的 element.height 还不一定含底部安全区(uniapp tabbar 经常
 * 用 position:fixed;bottom:0 + 安全区 padding 让元素视觉高度超过 rect.height)。
 *
 * 稳健做法:找视口底部 position:fixed 的元素,量它 top 距离 viewport bottom 的距离
 * (= 实际遮挡页面的总高,含 tabbar + 安全区 + 浏览器底部 toolbar)写回 CSS 变量。
 * 兼容 tabbar 高度变化、uniapp 类名变化、屏幕方向变化(resize 重测)。
 * uniapp 异步挂载 tabbar,最多重试 10 次 100ms。
 */
function measureTabBar(): boolean {
  // 策略 1:尝试 uniapp 常见 tabbar 选择器
  const tabbarSelectors = ['.uni-tabbar', '.uni-tabbar-bottom', '[class*="uni-tabbar"]']
  for (const sel of tabbarSelectors) {
    const el = document.querySelector(sel) as HTMLElement | null
    if (el) {
      const r = el.getBoundingClientRect()
      if (r.height > 0) {
        const covered = window.innerHeight - r.top
        document.documentElement.style.setProperty('--tab-bar-height', `${covered}px`)
        return true
      }
    }
  }
  // 策略 2:兜底 — 扫所有 fixed 元素,挑视口底部、高度合理(20~250)且最高的那个
  const all = document.body.querySelectorAll<HTMLElement>('*')
  let bestEl: HTMLElement | null = null
  let bestCovered = 0
  for (const el of all) {
    const s = getComputedStyle(el)
    if (s.position !== 'fixed') continue
    const r = el.getBoundingClientRect()
    if (r.height < 20 || r.height > 250) continue
    // 必须在视口下半部且贴底
    if (r.top < window.innerHeight / 2) continue
    const covered = window.innerHeight - r.top
    if (covered <= 0) continue
    if (covered > bestCovered) {
      bestEl = el
      bestCovered = covered
    }
  }
  if (bestEl && bestCovered > 0) {
    document.documentElement.style.setProperty('--tab-bar-height', `${bestCovered}px`)
    return true
  }
  console.warn('[TabBar] measure failed, fallback stays')
  return false
}
function setupTabBarHeight() {
  let attempts = 0
  const tryMeasure = () => {
    if (measureTabBar() || attempts >= 10) return
    attempts++
    setTimeout(tryMeasure, 100)
  }
  setTimeout(tryMeasure, 50)
  window.addEventListener('resize', () => setTimeout(measureTabBar, 100))
}
// #endif

onLaunch(async () => {
  theme.applySystemListener()
  lang.hydrate()
  // #ifdef H5
  setupTabBarHeight()
  // #endif
  if (!auth.token) {
    uni.reLaunch({ url: '/pages/login/index' })
    return
  }
  // 初始化阶段压制 1401 踢人 — H5 刷新当前页时,token 可能已失效,
  // 不该把用户从「资料编辑」这类已在操作的页面强制踢回登录页;
  // 让他们留在原页,token 留着,等下次主动 API 调用再决定要不要跳登录。
  await runSilent(async () => {
    try { await auth.me() } catch { /* 容忍 1401 */ }
    try { await book.reload() } catch { /* 容忍 */ }
  })
})
</script>

<template>
  <view class="app-root" :data-theme="theme.mode">
    <slot />
    <ToastHost />
  </view>
</template>

<style>
/* H5 全局:关掉 body 滚到顶/底的橡皮筋弹性效果。
   之前只在 .scroll-area 加了 overscroll-behavior:none,但 H5 上滚动在 body,
   scroll-view 不接管,所以弹性效果还在 —— 弹性会带动 sticky 元素一起滑动,
   看起来"导航栏跟着滚"。关 body 弹性后 sticky 元素才真的钉死。 */
html, body {
  overscroll-behavior: none;
}
/* H5 全局:禁止 body 自身滚动。所有页面都用 scroll-view 处理自己的滚动(已经如此),
   body 不需要再参与滚动 —— 否则 login 等不需要滚动的页面会被 body 拖动 */
html, body {
  height: 100%;
  overflow: hidden;
}
/* #ifdef H5 */
/* H5:uniapp 把 tabBar 渲染成 position:fixed 元素钉在底部,跟页面文档流无关。
   --tab-bar-height 在 onLaunch 里由 setupTabBarHeight() 实际测量后 setProperty 写入。
   fallback 直接用 80px 兜底(常见 tabBar 50~84px,80px 留点缓冲),
   不用 calc(60px + env(...)) 避免某些环境 env() 解析异常把整个变量作废成 0px。
   MP 原生 tabBar 占真实布局空间,这层覆盖对 MP 无副作用。 */
:root {
  --tab-bar-height: 80px;
}

/* H5 关键兜底(只对 5 个 tabBar 页生效,其余页 page-root 自然铺到底部):
   tabbar-page 类由 5 个 tabBar 页手动加到 page-root 上,
   这里用 .tabbar-page.page-root 锁定"既是 tabBar 页又是 page-root"。
   1) position:fixed + top:0 + bottom:var(--tab-bar-height) →
      把 page-root 直接钉到视口上(避开 body / 父级 / flex 计算的干扰),
      高度 = 视口 - tabBar,与 tabBar 完全相邻、内容最外层底部 = tabBar 顶部。
   2) height:auto → 让 top+bottom 决定高度,不要再用页面自己的 height:calc(100vh-...)
   3) .scroll-area min-height:0 → flex:1+height:0 子项能真正收缩(content 撑破 page-root 是
      "tabBar 盖内容" 的最大原因;flex 子项默认 min-height:auto 会拒绝收缩)
   4) .scroll-area overflow-y:auto → 显式声明,uniapp H5 编译的 scroll-view 偶尔不接管滚动
   5) .scroll-area padding-bottom:0 → page-root 已经钉到 tabBar 顶部,scroll-area 再带
      padding-bottom 就会在底部留一段空白,改成 0 让最末一项紧贴 tabBar 顶 */
.tabbar-page.page-root {
  position: fixed !important;
  top: 0 !important;
  left: 0 !important;
  right: 0 !important;
  bottom: var(--tab-bar-height, 80px) !important;
  height: auto !important;
  width: 100% !important;
}
.tabbar-page .scroll-area {
  min-height: 0 !important;
  overflow-y: auto !important;
  -webkit-overflow-scrolling: touch;
  padding-bottom: 0 !important;
}
/* H5 QuickAddModal 打开时挂 body.qa-open,把 uniapp 渲染的 .uni-tabbar 节点
   隐藏掉 — modal 应该是全屏遮罩,不该看到背后的 tabbar。
   MP/app-plus 的原生 tabBar 走 uni.hideTabBar/showTabBar 单独控制,不受这条影响。 */
body.qa-open .uni-tabbar,
body.qa-open .uni-tabbar-bottom {
  display: none !important;
}
/* H5 (iOS Safari) 把 body bg 涂成 navy —— WKWebView 内 body 撑到 viewport-fit=cover
   的整个屏幕,navy 就填到物理圆角那条窄边之外,跟 modal 内的 .qa-navy 同色,
   视觉上不留白。app-plus 不走这条路(受 UIWindow mask 限制),由原生插件
   qa-window-bg 在打包后把 UIWindow.backgroundColor 染同色,debug 不生效。
   !important + 同时染 html / #app,绕开 uniapp 默认白底、用户 UA 样式等所有
   上层覆盖。*/
html.qa-open,
body.qa-open,
body.qa-open #app,
body.qa-open .app-root {
  background: #141E3C !important;
}
/* #endif */
</style>
