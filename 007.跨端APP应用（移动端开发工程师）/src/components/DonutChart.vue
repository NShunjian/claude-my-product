<script setup lang="ts">
import { computed } from 'vue'

interface Segment { label: string; value: number; color: string }
const props = withDefaults(defineProps<{
  segments: Segment[]
  totalLabel?: string
  totalValue: string
}>(), {
  totalLabel: '',
  size: 200,
  strokeWidth: 24,
})

const radius = 70
const inner = 40
const cx = 100, cy = 100

const arcs = computed(() => {
  const total = props.segments.reduce((s, x) => s + x.value, 0) || 1
  let acc = 0
  return props.segments.map(s => {
    const start = (acc / total) * Math.PI * 2 - Math.PI / 2
    acc += s.value
    const end = (acc / total) * Math.PI * 2 - Math.PI / 2
    const large = end - start > Math.PI ? 1 : 0
    const x1 = cx + radius * Math.cos(start), y1 = cy + radius * Math.sin(start)
    const x2 = cx + radius * Math.cos(end),   y2 = cy + radius * Math.sin(end)
    const ix1 = cx + inner * Math.cos(end),   iy1 = cy + inner * Math.sin(end)
    const ix2 = cx + inner * Math.cos(start), iy2 = cy + inner * Math.sin(start)
    return {
      d: `M ${x1} ${y1} A ${radius} ${radius} 0 ${large} 1 ${x2} ${y2} L ${ix1} ${iy1} A ${inner} ${inner} 0 ${large} 0 ${ix2} ${iy2} Z`,
      color: s.color, label: s.label, value: s.value, pct: ((s.value / total) * 100).toFixed(1),
    }
  })
})
</script>

<template>
  <view class="wrap">
    <svg :width="200" :height="200" viewBox="0 0 200 200">
      <path v-for="(a, i) in arcs" :key="i" :d="a.d" :fill="a.color" />
      <text :x="cx" :y="cy - 6" text-anchor="middle" font-size="14" fill="var(--c-text-variant)">
        {{ totalLabel ?? '合计' }}
      </text>
      <text :x="cx" :y="cy + 16" text-anchor="middle" font-size="20" font-weight="700" fill="var(--c-text)">
        {{ totalValue }}
      </text>
    </svg>
    <view class="legend">
      <view v-for="(a, i) in arcs" :key="i" class="lg-row">
        <view class="dot" :style="{ background: a.color }" />
        <text class="lg-label">{{ a.label }}</text>
        <text class="lg-pct">{{ a.pct }}%</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.wrap { display: flex; flex-direction: column; align-items: center; gap: 24rpx; }
.legend { width: 100%; }
.lg-row { display: flex; align-items: center; gap: 12rpx; padding: 8rpx 0; }
.dot { width: 16rpx; height: 16rpx; border-radius: 50%; }
.lg-label { flex: 1; font-size: 26rpx; color: var(--c-text); }
.lg-pct { font-size: 24rpx; color: var(--c-text-variant); }
</style>
