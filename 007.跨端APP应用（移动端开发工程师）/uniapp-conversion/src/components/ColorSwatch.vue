<script setup lang="ts">
const props = defineProps<{ value: string }>()
const emit = defineEmits<{ (e: 'update:value', v: string): void }>()
const palette = ['#2E7DE6', '#BA1A1A', '#FFA000', '#388E3C', '#7B1FA2', '#A0AEC0']
function pick(c: string) { emit('update:value', c) }
</script>
<template>
  <view class="sw">
    <view
      v-for="c in palette" :key="c"
      class="dot"
      :class="{ active: c === value }"
      :style="{ background: c }"
      @tap="pick(c)"
    />
  </view>
</template>
<style scoped>
.sw { display: flex; gap: 16rpx; }
.dot { width: 48rpx; height: 48rpx; border-radius: 50%; border: 2px solid transparent; }
.dot.active { border-color: var(--c-primary); }
</style>
