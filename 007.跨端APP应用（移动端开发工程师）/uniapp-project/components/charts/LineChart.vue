<script setup lang="ts">
import { ref, computed } from 'vue'

interface Point { day: number; income: number; expense: number }
const props = withDefaults(defineProps<{
  data: Point[]
  incomeColor?: string
  expenseColor?: string
  smoothWindow?: number
}>(), {
  incomeColor: '#006d40',
  expenseColor: '#BA1A1A',
  smoothWindow: 5,
})

const W = 600, H = 300, pl = 40, pr = 16, pt = 16, pb = 32
const innerW = W - pl - pr, innerH = H - pt - pb

const hover = ref<{ idx: number; clientX: number; clientY: number } | null>(null)

// Asymmetric backward-looking window — matches React
function smooth(values: number[], w: number): number[] {
  if (w <= 1) return values
  return values.map((_, i) => {
    const start = Math.max(0, i - w + 1)
    const slice = values.slice(start, i + 1)
    return slice.reduce((s, v) => s + v, 0) / slice.length
  })
}

const YMAX = 4000

const xs = computed(() => props.data.map((_, i) => pl + (i / Math.max(1, props.data.length - 1)) * innerW))
const ys = (v: number) => pt + innerH - (v / YMAX) * innerH

const lineIncome = computed(() => {
  const sm = smooth(props.data.map(d => d.income), props.smoothWindow)
  return sm.map((v, i) => `${i === 0 ? 'M' : 'L'} ${xs.value[i]} ${ys(v)}`).join(' ')
})
const lineExpense = computed(() => {
  const sm = smooth(props.data.map(d => d.expense), props.smoothWindow)
  return sm.map((v, i) => `${i === 0 ? 'M' : 'L'} ${xs.value[i]} ${ys(v)}`).join(' ')
})

const yTicks = [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000]
const xTicks = computed(() => props.data.map(d => d.day))

function onTouch(e: any) {
  const touches = e?.touches?.[0]
  if (!touches) return
  const x = touches.x - pl
  const i = Math.round((x / innerW) * (props.data.length - 1))
  hover.value = { idx: Math.max(0, Math.min(props.data.length - 1, i)), clientX: touches.x, clientY: touches.y }
}
function clearHover() { hover.value = null }
</script>

<template>
  <view class="line-wrap">
    <svg :viewBox="`0 0 ${W} ${H}`" :width="W" :height="H"
         @touchstart="onTouch" @touchmove="onTouch" @touchend="clearHover">
      <!-- 9 horizontal grid lines + y-axis labels -->
      <g v-for="v in yTicks" :key="v">
        <line :x1="pl" :x2="W - pr" :y1="ys(v)" :y2="ys(v)"
              stroke="var(--c-divider)" stroke-dasharray="2 4" />
        <text :x="pl - 8" :y="ys(v)" text-anchor="end" dominant-baseline="middle"
              font-size="11" fill="#94a3b8">{{ v.toLocaleString('en-US') }}</text>
      </g>
      <!-- x-axis day ticks -->
      <text v-for="(day, i) in xTicks" :key="i"
            :x="xs[i]" :y="H - pb + 18" text-anchor="middle"
            font-size="11" fill="#94a3b8">{{ day }}</text>
      <path :d="lineIncome"  :stroke="incomeColor"  fill="none" stroke-width="2" />
      <path :d="lineExpense" :stroke="expenseColor" fill="none" stroke-width="2" />
      <circle v-for="(_, i) in props.data" :key="i" :cx="xs[i]" :cy="ys(props.data[i].income)"
              r="3" :fill="incomeColor" />
      <circle v-for="(_, i) in props.data" :key="i" :cx="xs[i]" :cy="ys(props.data[i].expense)"
              r="3" :fill="expenseColor" />
    </svg>
    <view v-if="hover" class="tip" :style="{ left: hover.clientX + 'px', top: hover.clientY + 'px' }">
      <view>Day {{ props.data[hover.idx].day }}</view>
      <view>+¥{{ props.data[hover.idx].income.toFixed(2) }}</view>
      <view>-¥{{ props.data[hover.idx].expense.toFixed(2) }}</view>
    </view>
  </view>
</template>

<style scoped>
.line-wrap { position: relative; width: 100%; }
svg { width: 100%; height: 300rpx; }
.tip {
  position: absolute; transform: translate(-50%, -120%);
  background: var(--c-bg-card); border: 1px solid var(--c-divider);
  border-radius: 8rpx; padding: 8rpx 12rpx; font-size: 22rpx; color: var(--c-text);
  pointer-events: none;
}
</style>
