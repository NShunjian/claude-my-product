<script setup lang="ts">
import { useToastStore } from '@/stores/toast'
const toast = useToastStore()
</script>

<template>
  <view class="toast-host">
    <view v-for="t in toast.items" :key="t.id" class="toast-item">{{ t.message }}</view>
  </view>
</template>

<style scoped>
.toast-host {
  position: fixed; top: 80rpx; left: 0; right: 0;
  display: flex; flex-direction: column; align-items: center;
  z-index: 9999; pointer-events: none;
}
.toast-item {
  background: rgba(0,0,0,.78); color: #fff;
  padding: 16rpx 32rpx; border-radius: 12rpx;
  margin-top: 12rpx; max-width: 80vw;
  font-size: 28rpx;
}
</style>
