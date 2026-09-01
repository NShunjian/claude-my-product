<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useBookStore } from '@/stores/book'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { useThemeStore } from '@/stores/theme'
import { LANGS } from '@/i18n/dict'

const auth = useAuthStore()
const book = useBookStore()
const toast = useToastStore()
const { t, lang, setLang } = useLanguage()
const theme = useThemeStore()

const username = ref('')
const password = ref('')
const busy = ref(false)

async function submit() {
  if (!username.value || !password.value) { toast.show(t('login.fillAll')); return }
  busy.value = true
  try {
    await auth.login({ username: username.value, password: password.value })
    // 登录成功后立刻拉账本列表,否则首页 watch 触发时 book.current 还是 null,load() 直接 return
    await book.reload()
    uni.reLaunch({ url: '/pages/index/index' })
  } catch (e: any) {
    toast.show(e?.message ?? t('login.opFailed'))
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <view class="login">
    <view class="head">
      <view class="logo-wrap"><text class="logo-text">Q</text></view>
      <text class="brand">{{ t('login.brandName') }}</text>
    </view>
    <view class="card">
      <view class="field">
        <text class="label">{{ t('login.username') }}</text>
        <input v-model="username" class="input" :placeholder="t('login.username')" type="text" />
      </view>
      <view class="field">
        <text class="label">{{ t('login.password') }}</text>
        <input v-model="password" class="input" :placeholder="t('login.password')" type="password" />
      </view>
      <button class="btn-primary" :disabled="busy" @tap="submit">
        {{ busy ? t('login.submitting') : t('login.submit') }}
      </button>
    </view>
    <view class="prefs">
      <picker mode="selector" :range="LANGS.map(l => l.label)" :value="LANGS.findIndex(l => l.code === lang)" @change="(e: any) => setLang(LANGS[Number(e.detail.value)].code)">
        <view class="pref-item">{{ LANGS.find(l => l.code === lang)?.label }}</view>
      </picker>
      <view class="pref-item" @tap="theme.setMode(theme.mode === 'dark' ? 'light' : 'dark')">
        {{ theme.mode === 'dark' ? '🌙' : '☀️' }}
      </view>
    </view>
  </view>
</template>

<style scoped>
.login { padding: 80rpx 48rpx; display: flex; flex-direction: column; gap: 48rpx; }
.head { display: flex; align-items: center; gap: 16rpx; justify-content: center; }
.logo-wrap { width: 80rpx; height: 80rpx; border-radius: 20rpx; background: var(--c-primary); display: flex; align-items: center; justify-content: center; }
.logo-text { color: #fff; font-weight: 700; font-size: 40rpx; }
.brand { font-size: 40rpx; font-weight: 700; }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 40rpx; display: flex; flex-direction: column; gap: 32rpx; border: 1px solid var(--c-divider); }
.field { display: flex; flex-direction: column; gap: 12rpx; }
.label { font-size: 28rpx; color: var(--c-text-variant); }
.input { border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 20rpx; background: var(--c-bg); color: var(--c-text); font-size: 30rpx; }
.btn-primary { background: var(--c-primary); color: #fff; border-radius: 12rpx; padding: 24rpx; font-size: 32rpx; font-weight: 600; }
.prefs { display: flex; gap: 16rpx; justify-content: flex-end; }
.pref-item { padding: 12rpx 20rpx; border-radius: 16rpx; background: var(--c-surface); font-size: 26rpx; }
</style>
