<script setup lang="ts">
import { onLaunch } from '@dcloudio/uni-app'
import { useAuthStore } from '@/stores/auth'
import { useBookStore } from '@/stores/book'
import { useThemeStore } from '@/stores/theme'
import { useLanguageStore } from '@/stores/language'
import ToastHost from '@/components/Toast.vue'

const auth = useAuthStore()
const book = useBookStore()
const theme = useThemeStore()
const lang  = useLanguageStore()

onLaunch(async () => {
  theme.applySystemListener()
  lang.hydrate()
  if (auth.token) {
    try { await auth.me() } catch { /* token invalid → reLaunch /login */ }
    try { await book.reload() } catch { /* 容忍 */ }
  }
})
</script>

<template>
  <view class="app-root" :data-theme="theme.mode">
    <slot />
    <ToastHost />
  </view>
</template>
