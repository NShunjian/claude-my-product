<script setup lang="ts">
import { ref, computed } from 'vue'
import { useLanguage } from '@/i18n/useLanguage'

interface Point { day: number; income: number; expense: number }
const props = withDefaults(defineProps<{
  data: Point[]
  incomeColor?: string
  expenseColor?: string
  smoothWindow?: number
}>(), {
  incomeColor: '#005394',
  expenseColor: '#ba1a1a',
  smoothWindow: 5,
})

const { t } = useLanguage()

const W = 800, H = 320
const PAD = { top: 20, right: 20, bottom: 40, left: 50 }
const innerW = W - PAD.left - PAD.right
const innerH = H - PAD.top - PAD.bottom

const hover = ref<{ idx: number; localX: number } | null>(null)
const svgEl = ref<any>(null)

// 平滑(移动平均)对齐 React
function smooth(values: number[], w: number): number[] {
  if (w <= 1) return values
  return values.map((_, i) => {
    const start = Math.max(0, i - w + 1)
    const slice = values.slice(start, i + 1)
    return slice.reduce((s, v) => s + v, 0) / slice.length
  })
}

const YMAX = 4000

const xs = computed(() => props.data.map((_, i) => PAD.left + (i / Math.max(1, props.data.length - 1)) * innerW))
const ys = (v: number) => PAD.top + innerH - (v / YMAX) * innerH

// Catmull-Rom → 三次贝塞尔(简化版),对齐 React
function smoothPath(values: number[]): string {
  if (values.length === 0) return ''
  const pts = values.map((v, i) => ({ x: xs.value[i], y: ys(v) }))
  let d = `M ${pts[0].x},${pts[0].y}`
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[i - 1] ?? pts[i]
    const p1 = pts[i]
    const p2 = pts[i + 1]
    const p3 = pts[i + 2] ?? p2
    const cp1x = p1.x + (p2.x - p0.x) / 6
    const cp1y = p1.y + (p2.y - p0.y) / 6
    const cp2x = p2.x - (p3.x - p1.x) / 6
    const cp2y = p2.y - (p3.y - p1.y) / 6
    d += ` C ${cp1x},${cp1y} ${cp2x},${cp2y} ${p2.x},${p2.y}`
  }
  return d
}

const lineIncome = computed(() => {
  const sm = smooth(props.data.map(d => d.income), props.smoothWindow)
  return smoothPath(sm.map(v => Math.min(v, YMAX)))
})
const lineExpense = computed(() => {
  const sm = smooth(props.data.map(d => d.expense), props.smoothWindow)
  return smoothPath(sm.map(v => Math.min(v, YMAX)))
})
// 收入曲线下方填充
const incomeArea = computed(() => {
  if (props.data.length === 0) return ''
  const first = xs.value[0]
  const last = xs.value[xs.value.length - 1]
  return lineIncome.value + ` L ${last},${ys(0)} L ${first},${ys(0)} Z`
})

const yTicks = [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000]
const xTicks = [1, 5, 10, 15, 20, 25, 30]

function pickIdx(clientX: number): number | null {
  const svg = svgEl.value
  if (!svg) return null
  // uni-app svg 用 getBoundingClientRect 在 h5/weapp 都可用
  const rect = svg.getBoundingClientRect ? svg.getBoundingClientRect() : null
  if (!rect || rect.width === 0) return null
  const vbX = ((clientX - rect.left) / rect.width) * W
  if (vbX < PAD.left - 10 || vbX > W - PAD.right + 10) return null
  const ratio = (vbX - PAD.left) / innerW
  const day = Math.round(ratio * (props.data.length - 1)) + 1
  return Math.max(0, Math.min(props.data.length - 1, day - 1))
}

function onTouch(e: any) {
  const touches = e?.touches?.[0]
  if (!touches) return
  const svg = svgEl.value
  if (!svg) return
  const offsetX = touches.x ?? touches.clientX ?? touches.pageX
  const idx = pickIdx(offsetX)
  if (idx === null) return
  // 转成相对 .line-wrap 的本地坐标(absolute 子元素需要这个)
  const rect = svg.getBoundingClientRect()
  hover.value = { idx, localX: offsetX - rect.left }
}
function onTouchEnd() {
  // 保持显示一段时间,让用户看清
  setTimeout(() => { hover.value = null }, 1500)
}
function clearHover() { hover.value = null }

const hoverData = computed(() => hover.value ? props.data[hover.value.idx] : null)
const hoverVbX = computed(() => hover.value ? xs.value[hover.value.idx] : 0)
// tooltip 顶部位置(以 max(income, expense) 为锚点),转换为相对 SVG 的百分比
const hoverTopPct = computed(() => {
  if (!hoverData.value || !hover.value) return '50%'
  const yVal = Math.max(hoverData.value.income, hoverData.value.expense)
  return `${(ys(Math.min(yVal, YMAX)) / H) * 100}%`
})
// tooltip 锚点:触点在右半用右对齐(-100%)避免溢出 chart card,左半居中
const tipAnchor = computed(() => {
  if (!hover.value || !svgEl.value) return 'center'
  const rect = svgEl.value.getBoundingClientRect()
  return hover.value.localX > rect.width / 2 ? 'right' : 'center'
})
</script>

<template>
  <view class="line-wrap">
    <svg ref="svgEl" :viewBox="`0 0 ${W} ${H}`" preserveAspectRatio="xMidYMid meet"
         @touchstart="onTouch" @touchmove="onTouch" @touchend="onTouchEnd">
      <!-- 网格线 -->
      <g v-for="v in yTicks" :key="v">
        <line :x1="PAD.left" :x2="W - PAD.right" :y1="ys(v)" :y2="ys(v)"
              stroke="#E2E8F0" stroke-width="1" />
      </g>
      <!-- 收入填充 -->
      <path :d="incomeArea" :fill="incomeColor" fill-opacity="0.1" />
      <!-- 收入曲线 -->
      <path :d="lineIncome" :stroke="incomeColor" fill="none"
            stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
      <!-- 支出曲线 -->
      <path :d="lineExpense" :stroke="expenseColor" fill="none"
            stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
      <!-- 悬停十字虚线 -->
      <line v-if="hover" :x1="hoverVbX" :x2="hoverVbX"
            :y1="PAD.top" :y2="H - PAD.bottom"
            stroke="#94a3b8" stroke-width="1" stroke-dasharray="3 3" />
      <!-- 悬停数据点圆环 -->
      <template v-if="hoverData">
        <circle :cx="hoverVbX" :cy="ys(Math.min(hoverData.income, YMAX))" r="5"
                fill="#fff" :stroke="incomeColor" stroke-width="2" />
        <circle :cx="hoverVbX" :cy="ys(Math.min(hoverData.expense, YMAX))" r="5"
                fill="#fff" :stroke="expenseColor" stroke-width="2" />
      </template>
    </svg>
    <!-- 轴标签:HTML 覆盖层(SVG text 在 H5 渲染不稳定,改用 HTML 定位,百分比跟 viewBox 对齐) -->
    <text v-for="v in yTicks" :key="`y-${v}`" class="axis-y"
          :style="{ left: (PAD.left / W * 100) + '%', top: (ys(v) / H * 100) + '%' }">
      {{ v.toLocaleString('en-US') }}
    </text>
    <text v-for="d in xTicks" :key="`x-${d}`" class="axis-x"
          :style="{ left: (xs[d - 1] / W * 100) + '%', top: ((H - PAD.bottom + 18) / H * 100) + '%' }">
      {{ d }}
    </text>
    <!-- Tooltip(HTML 覆盖层,跟随触点位置) -->
    <view v-if="hoverData && hover" class="tip" :class="`tip-${tipAnchor}`"
          :style="{ left: hover.localX + 'px', top: hoverTopPct }">
      <view class="tip-day">{{ hoverData.day }}</view>
      <view class="tip-row">
        <view class="tip-swatch" :style="{ borderColor: incomeColor }" />
        <text class="tip-text">{{ t('chart.line.income') }}: {{ Math.round(hoverData.income).toLocaleString('en-US') }}</text>
      </view>
      <view class="tip-row">
        <view class="tip-swatch" :style="{ borderColor: expenseColor }" />
        <text class="tip-text">{{ t('chart.line.expense') }}: {{ Math.round(hoverData.expense).toLocaleString('en-US') }}</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.line-wrap { position: relative; width: 100%; }
svg { width: 100%; height: auto; display: block; }
/* 轴标签(HTML 覆盖层,SVG text 在 H5 不稳) */
.axis-y {
  position: absolute;
  transform: translate(-100%, -50%);
  font-size: 11px;
  color: #64748b;
  line-height: 1;
  white-space: nowrap;
  pointer-events: none;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
.axis-x {
  position: absolute;
  transform: translate(-50%, 0);
  font-size: 11px;
  color: #64748b;
  line-height: 1;
  pointer-events: none;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
}
.tip {
  position: absolute; transform: translate(-50%, -110%);
  background: var(--c-bg-card); border: 1px solid var(--c-divider);
  border-radius: 8rpx; padding: 12rpx 16rpx; font-size: 22rpx; color: var(--c-text);
  box-shadow: 0 4rpx 12rpx rgba(0, 0, 0, 0.08);
  pointer-events: none; min-width: 140rpx;
}
.tip-right { transform: translate(-100%, -110%); }
.tip-day { font-weight: 700; font-size: 24rpx; margin-bottom: 4rpx; color: var(--c-text); }
.tip-row { display: flex; align-items: center; gap: 8rpx; margin-top: 4rpx; }
.tip-swatch { width: 10rpx; height: 10rpx; background: transparent; border: 2rpx solid; border-radius: 2rpx; }
.tip-text { font-size: 22rpx; color: var(--c-text); }
</style>