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
