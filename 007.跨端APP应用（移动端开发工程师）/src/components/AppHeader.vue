<script setup lang="ts">
import { useLanguageStore } from '@/stores/language'
defineProps<{ title: string; back?: boolean }>()
const lang = useLanguageStore()
</script>
<template>
  <view class="app-header">
    <view v-if="back" class="back-btn" @tap="$emit('back')">
      <text>‹</text>
    </view>
    <view class="title">{{ title }}</view>
    <slot name="right" />
  </view>
</template>
<style scoped>
.app-header { display: flex; align-items: center; height: 88rpx; padding: 0 24rpx; background: var(--c-bg); border-bottom: 1px solid var(--c-divider); }
.back-btn { width: 64rpx; font-size: 48rpx; color: var(--c-text); }
.title { flex: 1; text-align: center; font-weight: 600; color: var(--c-text); }
</style>
