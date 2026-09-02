<script setup lang="ts">
import { ref, computed, watch, getCurrentInstance } from 'vue'
import { useLanguage } from '@/i18n/useLanguage'

// 收入/支出占比环图。H5 走 SVG(浏览器原生支持),MP 走 view + conic-gradient。
//
// 为什么不用 canvas:uniapp vue3 + mp 编译器对 <canvas type="2d"> 处理不稳定,
// 多次实测即使设了 libVersion 2.32.3 仍不渲染。conic-gradient 是 wxss 标准
// 支持(基础库 2.13.0+),配合 background-color 兜底,即使 conic-gradient 被忽略
// 也至少显示单色 ring + 中心文字,绝对不空白。
//
// 对外接口不变(:segments / :totalValue / :totalLabel / :hideLegend),
// monthly.vue 不需要改。

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

// ========================= H5: SVG 实现(完全保留原逻辑) =========================
// #ifdef H5
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
    if (props.segments.length === 1) {
      end = start + Math.PI * 2 - 0.001
    }
    const mid = (start + end) / 2
    const large = end - start > Math.PI ? 1 : 0
    const x1 = cx + radius * Math.cos(start), y1 = cy + radius * Math.sin(start)
    const x2 = cx + radius * Math.cos(end),   y2 = cy + radius * Math.sin(end)
    const ix1 = cx + inner * Math.cos(end),   iy1 = cy + inner * Math.sin(end)
    const ix2 = cx + inner * Math.cos(start), iy2 = cy + inner * Math.sin(start)
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
  touchTimer = setTimeout(() => { hoverIdx.value = null; touchTimer = null }, 2000)
}
function clearHover() {
  hoverIdx.value = null
  if (touchTimer) { clearTimeout(touchTimer); touchTimer = null }
}
// #endif

// ========================= MP: conic-gradient 环图 =========================
// #ifdef MP-WEIXIN
//
// 拼接 conic-gradient stop 字符串。mp 基础库 2.13.0+ 完全支持;
// 设 background-color 兜底,如果 conic-gradient 被忽略,显示单色 ring + 中心文字。

const conicStops = computed(() => {
  if (props.segments.length === 0) return ''
  const total = props.segments.reduce((s, x) => s + x.value, 0) || 1
  const stops: string[] = []
  let acc = 0
  for (const s of props.segments) {
    const startDeg = (acc / total) * 360
    acc += s.value
    const endDeg = (acc / total) * 360
    stops.push(`${s.color} ${startDeg}deg ${endDeg}deg`)
  }
  return stops.join(', ')
})

const fallbackBg = computed(() => {
  // conic-gradient 不支持时,显示首个 segment 颜色(或灰)
  return props.segments[0]?.color ?? '#E2E8F0'
})

// MP 点击浮窗:conic-gradient 没有可交互的元素,所以用透明覆盖层捕获触摸位置,
// 用 (dx, dy) → 角度 → segment index 的方式反推命中。
// 浮窗位置放在命中 segment 的中线 + 外侧(对齐 H5 seg-tip 视觉)。
const mpTipIdx = ref<number | null>(null)
const mpTipLeftPct = ref('50%')
const mpTipTopPct = ref('50%')
const mpTipAnchor = ref<'left' | 'right' | 'center'>('center')
let mpTipTimer: ReturnType<typeof setTimeout> | null = null
const donutIns = getCurrentInstance()

function queryDonutRect(): Promise<{ left: number; top: number; width: number; height: number } | null> {
  return new Promise((resolve) => {
    const q = uni.createSelectorQuery().in(donutIns)
    q.select('.mp-donut-ring').boundingClientRect()
    q.exec((res: any) => resolve((res && res[0]) || null))
  })
}

// 几何参数:ring 320rpx 直径,hole 200rpx 直径,所以有效 ring 半径 = (160 - 100) = 60rpx
// 触摸判定的内外径 = (60, 160),tol = ±15
const MP_RING_PX = 320
const MP_HOLE_PX = 200

function findSegmentAt(localX: number, localY: number, size: number): number | null {
  if (props.segments.length === 0) return null
  const cx = size / 2
  const cy = size / 2
  const rOuter = size / 2
  const rInner = (MP_HOLE_PX / MP_RING_PX) * size / 2
  const dx = localX - cx
  const dy = localY - cy
  const dist = Math.hypot(dx, dy)
  if (dist < rInner || dist > rOuter) return null
  // atan2 → 数学角(0 = 3 点钟,逆时针为正);转成 conic 角(0 = 12 点钟,顺时针为正)
  let deg = Math.atan2(dy, dx) * 180 / Math.PI + 90
  if (deg < 0) deg += 360
  if (deg >= 360) deg -= 1e-6
  const total = props.segments.reduce((s, x) => s + x.value, 0) || 1
  let acc = 0
  for (let i = 0; i < props.segments.length; i++) {
    const s = props.segments[i]
    const startDeg = (acc / total) * 360
    acc += s.value
    const endDeg = (acc / total) * 360
    if (deg >= startDeg && deg < endDeg) return i
  }
  return props.segments.length - 1
}

function onDonutTouch(e: any) {
  // MP @touchstart 在不同基础库 / 真机下,坐标字段不统一(touches / changedTouches / detail.x 都有)
  // 逐级兜底,且必须是数字才用
  let x: number | undefined
  let y: number | undefined
  const list = [e?.touches?.[0], e?.changedTouches?.[0]].filter(Boolean) as any[]
  for (const t of list) {
    const tx = Number(t.x ?? t.clientX ?? t.pageX)
    const ty = Number(t.y ?? t.clientY ?? t.pageY)
    if (!isNaN(tx) && !isNaN(ty)) {
      x = tx
      y = ty
      break
    }
  }
  if (x === undefined || y === undefined) return
  queryDonutRect().then((rect) => {
    if (!rect || rect.width === 0) return
    const localX = x! - rect.left
    const localY = y! - rect.top
    const idx = findSegmentAt(localX, localY, rect.width)
    if (idx === null) {
      // 点中心孔 / 外圈之外 → 关闭浮窗
      mpTipIdx.value = null
      return
    }
    // 浮窗位置:命中 segment 的中线角,往外挪 12rpx
    const total = props.segments.reduce((s, x) => s + x.value, 0) || 1
    let acc = 0
    for (let i = 0; i < idx; i++) acc += props.segments[i].value
    const startDeg = (acc / total) * 360
    const endDeg = ((acc + props.segments[idx].value) / total) * 360
    const midDeg = (startDeg + endDeg) / 2
    const midRad = (midDeg - 90) * Math.PI / 180
    const tipR = rect.width / 2 + 12  // 12rpx 外侧
    const tipX = rect.width / 2 + Math.cos(midRad) * tipR
    const tipY = rect.height / 2 + Math.sin(midRad) * tipR
    mpTipLeftPct.value = `${(tipX / rect.width) * 100}%`
    mpTipTopPct.value = `${(tipY / rect.height) * 100}%`
    // 贴边翻转:cos > 0.3 → 浮窗往左偏(避免右侧超出屏幕)
    const c = Math.cos(midRad)
    mpTipAnchor.value = c > 0.3 ? 'right' : c < -0.3 ? 'left' : 'center'
    mpTipIdx.value = idx
    if (mpTipTimer) clearTimeout(mpTipTimer)
    mpTipTimer = setTimeout(() => {
      mpTipIdx.value = null
      mpTipTimer = null
    }, 2000)
  })
}

const mpTipSeg = computed(() => {
  const idx = mpTipIdx.value
  if (idx === null) return null
  return props.segments[idx] ?? null
})
const mpTipPct = computed(() => {
  const seg = mpTipSeg.value
  if (!seg) return '0.0'
  const total = props.segments.reduce((s, x) => s + x.value, 0) || 1
  return ((seg.value / total) * 100).toFixed(1)
})

// 数据源切换时清掉 tooltip
watch(() => props.segments, () => {
  mpTipIdx.value = null
  if (mpTipTimer) { clearTimeout(mpTipTimer); mpTipTimer = null }
})
// #endif
</script>

<template>
  <view class="wrap">
    <!-- H5: 原 SVG 实现 -->
    <!-- #ifdef H5 -->
    <view class="donut-wrap" @tap="clearHover">
      <svg :viewBox="`0 0 ${W} ${H}`" preserveAspectRatio="xMidYMid meet" class="donut-svg">
        <path v-for="(a, i) in arcs" :key="i"
              :d="a.d"
              :fill="a.color"
              :class="['seg', { active: hoverIdx === i }]"
              @tap.stop="onTap(i)"
              @touchstart.stop="onTap(i)" />
      </svg>
      <view class="center-text">
        <text class="total-label">{{ finalTotalLabel }}</text>
        <text class="total-value">{{ totalValue }}</text>
      </view>
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
    <!-- #endif -->

    <!-- MP: view + conic-gradient 环图(conic 不支持时退化单色 ring + 中心文字) -->
    <!-- #ifdef MP-WEIXIN -->
    <view class="mp-donut-wrap">
      <view class="mp-donut-stack">
        <view class="mp-donut-ring"
              :style="{
                background: conicStops ? `conic-gradient(${conicStops})` : fallbackBg,
                'background-color': fallbackBg,
              }">
          <view class="mp-donut-hole">
            <text class="mp-donut-label">{{ finalTotalLabel }}</text>
            <text class="mp-donut-total">{{ totalValue }}</text>
          </view>
        </view>
        <!-- 透明覆盖层:捕获触摸位置 → 角度反推 segment -->
        <view class="mp-donut-touch" @touchstart="onDonutTouch" />
        <!-- 浮窗:放在命中 segment 的中线角 + 外侧 12rpx(对齐 H5 seg-tip 视觉) -->
        <view v-if="mpTipIdx !== null"
              class="mp-donut-tip"
              :class="`mp-donut-tip-${mpTipAnchor}`"
              :style="{ left: mpTipLeftPct, top: mpTipTopPct }">
          <view class="mp-donut-tip-row">
            <view class="mp-donut-tip-dot"
                  :style="{ borderColor: mpTipSeg?.color }" />
            <text class="mp-donut-tip-label">{{ mpTipSeg?.label }}</text>
          </view>
          <text class="mp-donut-tip-value">¥{{ Math.round(mpTipSeg?.value || 0).toLocaleString('en-US') }}</text>
          <text class="mp-donut-tip-pct">{{ mpTipPct }}%</text>
        </view>
      </view>
    </view>
    <!-- #endif -->
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

/* MP: conic-gradient 环图 */
.mp-donut-wrap {
  width: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 16rpx 0;
}
.mp-donut-stack {
  position: relative;
  width: 320rpx;
  height: 320rpx;
}
.mp-donut-ring {
  width: 320rpx;
  height: 320rpx;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
}
.mp-donut-hole {
  width: 200rpx;
  height: 200rpx;
  border-radius: 50%;
  background: var(--c-bg-card);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 4rpx;
}
.mp-donut-label {
  font-size: 22rpx;
  color: var(--c-text-variant);
  line-height: 1.2;
}
.mp-donut-total {
  font-size: 30rpx;
  font-weight: 700;
  color: var(--c-text);
  line-height: 1.2;
}

/* MP: 触摸覆盖层 + 浮窗(对齐 H5 seg-tip) */
.mp-donut-touch {
  position: absolute;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  /* rgba(0,0,0,0.001) 而非 transparent:mp 上某些版本 transparent 不产生 hit area */
  background: rgba(0, 0, 0, 0.001);
  z-index: 2;
}
.mp-donut-tip {
  position: absolute;
  transform: translate(-50%, -50%);
  background: var(--c-bg-card);
  border: 1rpx solid var(--c-divider);
  border-radius: 12rpx;
  padding: 12rpx 16rpx;
  min-width: 160rpx;
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.12);
  pointer-events: none;
  z-index: 10;
}
.mp-donut-tip-right { transform: translate(-100%, -50%); }
.mp-donut-tip-left  { transform: translate(0,      -50%); }
.mp-donut-tip-center { transform: translate(-50%, -50%); }
.mp-donut-tip-row { display: flex; align-items: center; gap: 8rpx; margin-bottom: 6rpx; }
.mp-donut-tip-dot {
  width: 12rpx; height: 12rpx;
  background: transparent;
  border: 2rpx solid;
  border-radius: 4rpx;
}
.mp-donut-tip-label { font-size: 22rpx; font-weight: 700; color: var(--c-text); }
.mp-donut-tip-value { display: block; font-size: 22rpx; color: var(--c-text); margin-top: 2rpx; }
.mp-donut-tip-pct { display: block; font-size: 20rpx; color: var(--c-text-variant); margin-top: 4rpx; }
</style>
