<script setup lang="ts">
import { computed } from 'vue'
import { formatMonthCN } from '@/utils/date'
const props = defineProps<{ modelValue: string }>() // 'YYYY-MM'
const emit = defineEmits<{ (e: 'update:modelValue', v: string): void }>()

const label = computed(() => formatMonthCN(props.modelValue))

function step(delta: number) {
  let m = Number(props.modelValue.slice(5, 7)) + delta
  let y = Number(props.modelValue.slice(0, 4))
  if (m < 1) { m = 12; y -= 1 }
  if (m > 12) { m = 1; y += 1 }
  emit('update:modelValue', `${y}-${String(m).padStart(2, '0')}`)
}
</script>
<template>
  <view class="mp">
    <view class="btn" @tap="step(-1)">‹</view>
    <view class="label">{{ label }}</view>
    <view class="btn" @tap="step(1)">›</view>
  </view>
</template>
<style scoped>
.mp { display: flex; align-items: center; gap: 8rpx; padding: 8rpx 24rpx; border-radius: 32rpx; background: var(--c-bg-card); border: 1px solid var(--c-divider); }
.btn { width: 56rpx; height: 56rpx; display: flex; align-items: center; justify-content: center; font-size: 40rpx; color: var(--c-text-variant); line-height: 1; }
.label { font-size: 30rpx; font-weight: 600; padding: 0 12rpx; }
</style>
