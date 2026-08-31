<script setup lang="ts">
import type { Category } from '@/api/categories'
defineProps<{ category: Category; size?: 'sm' | 'md' }>()
</script>
<template>
  <view class="badge" :class="size === 'sm' ? 'sm' : 'md'"
        :style="{ background: category.color + '33' }">
    <text class="ic">{{ category.icon }}</text>
    <text class="nm">{{ category.name }}</text>
  </view>
</template>
<style scoped>
.badge { display: inline-flex; align-items: center; gap: 8rpx; border-radius: 16rpx; padding: 4rpx 12rpx; }
.sm { font-size: 22rpx; } .md { font-size: 26rpx; }
.ic { font-size: 28rpx; } .nm { color: var(--c-text); }
</style>
