<script setup lang="ts">
import { ref } from 'vue'
defineProps<{ title: string; back?: boolean }>()

// 微信小程序 / app 需要让出顶部状态栏;h5 这里 statusBarHeight=0,不占空间
const statusBarHeight = ref(0)
// #ifdef MP-WEIXIN || APP-PLUS
try {
  const sys = uni.getSystemInfoSync()
  statusBarHeight.value = sys.statusBarHeight ?? 0
} catch { /* 旧基础库可能拿不到,fallback 0 */ }
// #endif
</script>

<template>
  <view class="app-header-wrapper">
    <view class="status-bar" :style="{ height: statusBarHeight + 'px' }" />
    <view class="app-header">
      <view v-if="back" class="back-btn" @tap="$emit('back')">
        <text>‹</text>
      </view>
      <view class="title">{{ title }}</view>
      <slot name="right" />
    </view>
  </view>
</template>

<style scoped>
.app-header-wrapper {
  /* flex-shrink: 0 在页面 flex column 里自然占顶部空间(scroll-view 永远在它下方,不会遮挡)。
     sticky + top:0 在 H5 上把 AppHeader 钉在视口顶部:因为 H5 是 body 滚动,
     AppHeader 的滚动祖先是 body,sticky 元素随 body 滚动但视觉上钉住。
     MP 上 scroll-view 自己滚动,AppHeader 不在 scroll 内,sticky 找不到滚动祖先(整个 page 不滚)
     —— 此时靠 flex-shrink:0 自然占空间,内容在它下方,不会遮挡。 */
  position: sticky;
  top: 0;
  z-index: 100;
  flex-shrink: 0;
  background: var(--c-bg);
}
.status-bar { width: 100%; }
.app-header {
  display: flex;
  align-items: center;
  height: 88rpx;
  padding: 0 24rpx;
  background: var(--c-bg);
  border-bottom: 1px solid var(--c-divider);
}
.back-btn {
  width: 64rpx;
  font-size: 48rpx;
  color: var(--c-text);
}
.title {
  flex: 1;
  text-align: center;
  font-weight: 600;
  color: var(--c-text);
}
</style>