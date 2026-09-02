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

onLaunch(async () => {
  theme.applySystemListener()
  lang.hydrate()
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
</style>
