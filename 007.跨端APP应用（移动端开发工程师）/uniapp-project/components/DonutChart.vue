<script setup lang="ts">
import { ref, computed } from 'vue'
import { useLanguage } from '@/i18n/useLanguage'

interface Segment { label: string; value: number; color: string }
const props = withDefaults(defineProps<{
  segments: Segment[]
  totalLabel?: string
  totalValue: string
  hideLegend?: boolean
}>(), {
  totalLabel: '',
  hideLegend: false,
  size: 200,
  strokeWidth: 24,
})

const { t } = useLanguage()
const finalTotalLabel = computed(() => props.totalLabel || t('chart.donutTotal'))

const radius = 70
const inner = 40
const cx = 100, cy = 100
const W = 200, H = 200

const hoverIdx = ref<number | null>(null)
let touchTimer: ReturnType<typeof setTimeout> | null = null

const arcs = computed(() => {
  const total = props.segments.reduce((s, x) => s + x.value, 0) || 1
  let acc = 0
  return props.segments.map((s, i) => {
    const start = (acc / total) * Math.PI * 2 - Math.PI / 2
    acc += s.value
    let end = (acc / total) * Math.PI * 2 - Math.PI / 2
    // 单个 segment 占 100% 时 start(=-π/2) 与 end(=3π/2) 是同一方向,
    // SVG 弧线从同一点回到同一点会塌陷不渲染;直接让它绕整圈减去极小角度
    if (props.segments.length === 1) {
      end = start + Math.PI * 2 - 0.001
    }
    const mid = (start + end) / 2
    const large = end - start > Math.PI ? 1 : 0
    const x1 = cx + radius * Math.cos(start), y1 = cy + radius * Math.sin(start)
    const x2 = cx + radius * Math.cos(end),   y2 = cy + radius * Math.sin(end)
    const ix1 = cx + inner * Math.cos(end),   iy1 = cy + inner * Math.sin(end)
    const ix2 = cx + inner * Math.cos(start), iy2 = cy + inner * Math.sin(start)
    // tooltip 锚点:圆环外侧一段距离,百分比定位随容器缩放
    const tipR = radius + 12
    const tipX = ((cx + Math.cos(mid) * tipR) / W) * 100
    const tipY = ((cy + Math.sin(mid) * tipR) / H) * 100
    return {
      d: `M ${x1} ${y1} A ${radius} ${radius} 0 ${large} 1 ${x2} ${y2} L ${ix1} ${iy1} A ${inner} ${inner} 0 ${large} 0 ${ix2} ${iy2} Z`,
      color: s.color, label: s.label, value: s.value,
      pct: ((s.value / total) * 100).toFixed(1),
      tipX, tipY,
    }
  })
})

function onTap(i: number) {
  hoverIdx.value = i
  if (touchTimer) clearTimeout(touchTimer)
  // 触摸后保持 2s 显示(对齐 React)
  touchTimer = setTimeout(() => { hoverIdx.value = null; touchTimer = null }, 2000)
}
function clearHover() {
  hoverIdx.value = null
  if (touchTimer) { clearTimeout(touchTimer); touchTimer = null }
}
</script>

<template>
  <view class="wrap">
    <view class="donut-wrap" @tap="clearHover">
      <svg :viewBox="`0 0 ${W} ${H}`" preserveAspectRatio="xMidYMid meet" class="donut-svg">
        <path v-for="(a, i) in arcs" :key="i"
              :d="a.d"
              :fill="a.color"
              :class="['seg', { active: hoverIdx === i }]"
              @tap.stop="onTap(i)"
              @touchstart.stop="onTap(i)" />
      </svg>
      <!-- 中心文字(SVG text 在 H5 不渲染,改 HTML 覆盖层) -->
      <view class="center-text">
        <text class="total-label">{{ finalTotalLabel }}</text>
        <text class="total-value">{{ totalValue }}</text>
      </view>
      <!-- 扇区 tooltip(对齐 React:外侧定位 + 颜色边框小方块 + 类别/金额/百分比) -->
      <view v-if="hoverIdx !== null && arcs[hoverIdx]" class="seg-tip"
            :style="{ left: arcs[hoverIdx].tipX + '%', top: arcs[hoverIdx].tipY + '%' }">
        <view class="seg-tip-row">
          <view class="seg-tip-dot" :style="{ borderColor: arcs[hoverIdx].color }" />
          <text class="seg-tip-label">{{ arcs[hoverIdx].label }}</text>
        </view>
        <text class="seg-tip-value">¥{{ Math.round(arcs[hoverIdx].value).toLocaleString('en-US') }}</text>
        <text class="seg-tip-pct">{{ arcs[hoverIdx].pct }}%</text>
      </view>
    </view>
    <view v-if="!hideLegend" class="legend">
      <view v-for="(a, i) in arcs" :key="i" class="lg-row">
        <view class="dot" :style="{ background: a.color }" />
        <text class="lg-label">{{ a.label }}</text>
        <text class="lg-pct">{{ a.pct }}%</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.wrap { display: flex; flex-direction: column; align-items: stretch; gap: 24rpx; width: 100%; }
.donut-wrap { position: relative; width: 100%; padding-bottom: 100%; height: 0; margin-top: -60rpx; }
.donut-svg { position: absolute; inset: 0; width: 100%; height: 100%; display: block; }
.seg { transition: opacity 0.15s ease-out; }
.seg.active { opacity: 0.85; }
.center-text {
  position: absolute; inset: 0;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  pointer-events: none;
}
.total-label { font-size: 22rpx; color: var(--c-text-variant); }
.total-value { font-size: 32rpx; font-weight: 700; color: var(--c-text); margin-top: 4rpx; }
.seg-tip {
  position: absolute;
  transform: translate(-50%, -50%);
  background: var(--c-bg-card);
  border: 1px solid var(--c-divider);
  border-radius: 12rpx;
  padding: 12rpx 16rpx;
  min-width: 140rpx;
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.12);
  pointer-events: none;
  z-index: 10;
}
.seg-tip-row { display: flex; align-items: center; gap: 8rpx; margin-bottom: 6rpx; }
.seg-tip-dot { width: 12rpx; height: 12rpx; background: transparent; border: 2rpx solid; border-radius: 2rpx; }
.seg-tip-label { font-size: 22rpx; font-weight: 700; color: var(--c-text); }
.seg-tip-value { display: block; font-size: 22rpx; color: var(--c-text); margin-top: 2rpx; }
.seg-tip-pct { display: block; font-size: 20rpx; color: var(--c-text-variant); margin-top: 4rpx; }
.legend { width: 100%; }
.lg-row { display: flex; align-items: center; gap: 12rpx; padding: 8rpx 0; }
.dot { width: 16rpx; height: 16rpx; border-radius: 50%; }
.lg-label { flex: 1; font-size: 26rpx; color: var(--c-text); }
.lg-pct { font-size: 24rpx; color: var(--c-text-variant); }
</style>