<script setup lang="ts">
import { ref } from 'vue'
import { modalOpen } from '@/utils/modal-state'
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
  <!-- modal-open:QuickAddModal 打开时会挂 modalOpen=true,这里 AppHeader 整段 display:none。
       iOS WKWebView 里 .qa-overlay 偶尔压不住 sticky 的 AppHeader(z-index 10000 vs 100 失效),
       让 AppHeader 直接消失最稳;H5/MP 上原本就被遮罩盖住,效果一致。
       见 utils/modal-state.ts 注释。 -->
  <view class="app-header-wrapper" :class="{ 'modal-open': modalOpen }">
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
/* modal 打开时整段 AppHeader 隐藏 — iOS 修 WKWebView sticky 元素 elevated stacking
   压不过 overlay 的问题。H5/MP 上原本就被半透明遮罩盖住,这里变成 display:none,
   视觉效果一致。 */
.app-header-wrapper.modal-open {
  display: none;
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