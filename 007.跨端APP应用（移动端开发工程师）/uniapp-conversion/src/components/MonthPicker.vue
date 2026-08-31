<script setup lang="ts">
import { computed } from 'vue'
const props = defineProps<{ modelValue: string }>() // 'YYYY-MM'
const emit = defineEmits<{ (e: 'update:modelValue', v: string): void }>()

const year = computed(() => Number(props.modelValue.slice(0, 4)))
const month = computed(() => Number(props.modelValue.slice(5, 7)))

function step(delta: number) {
  let m = month.value + delta
  let y = year.value
  if (m < 1) { m = 12; y -= 1 }
  if (m > 12) { m = 1; y += 1 }
  emit('update:modelValue', `${y}-${String(m).padStart(2, '0')}`)
}
</script>
<template>
  <view class="mp">
    <view class="btn" @tap="step(-1)">‹</view>
    <view class="label">{{ year }}-{{ String(month).padStart(2, '0') }}</view>
    <view class="btn" @tap="step(1)">›</view>
  </view>
</template>
<style scoped>
.mp { display: flex; align-items: center; gap: 24rpx; }
.btn { width: 60rpx; height: 60rpx; border-radius: 30rpx; background: var(--c-surface); display: flex; align-items: center; justify-content: center; font-size: 36rpx; }
.label { font-size: 32rpx; font-weight: 600; }
</style>
