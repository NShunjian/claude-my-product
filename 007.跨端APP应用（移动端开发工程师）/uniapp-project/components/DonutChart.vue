<script setup lang="ts">
import { ref, computed, watch, getCurrentInstance } from 'vue'
import { useLanguage } from '@/i18n/useLanguage'

// 收入/支出占比环图。H5 走原生 <svg>,MP/APP-PLUS 走 SVG → data URI → <image>,
// 与 components/charts/LineChart.vue 的 mp 路线对齐。
//
// 为什么不用 canvas:uniapp vue3 + mp 编译器对 <canvas type="2d"> 处理不稳定,
// 多次实测即使设了 libVersion 2.32.3 仍不渲染。
//
// 为什么不用 conic-gradient:实测在 Android/iOS APP-PLUS webview 上不渲染
//(中心文字在,ring 是白的 — :style 里的 background/conic-gradient 被解析后丢了),
// 2026-09 改走 SVG data URI 跟 LineChart 一致。
//
// 对外接口不变(:segments / :totalValue / :totalLabel / :hideLegend),
// monthly.vue 不需要改。

// ========================= 防撞色去重 =========================
// 对齐 003 React lib/chart-color.ts 与 007 Flutter core/utils/chart_color.dart:
// 同一图表内出现 ≥2 个 hex 相同的扇区时,挨个差异化。
//   - **彩色**(S ≥ 0.20):调 L ±20% 阶梯,保留色相。
//   - **灰/低饱和**(S < 0.20):加饱和 + 偏色相,让肉眼能区分。
// 第 1 个保持原色,第 2 个 +L,第 3 个 -L,第 4 个 +2L,第 5 个 -2L …
// uniapp vue3 SFC 不便引外部工具,这里 inline 一份。
function deduplicateColors<T extends { color: string }>(segs: T[]): T[] {
  if (segs.length <= 1) return segs.map(s => ({ ...s }))
  const sameIdx: Record<string, number> = {}
  return segs.map((s) => {
    const key = s.color.trim().toUpperCase()
    const idx = sameIdx[key] ?? 0
    sameIdx[key] = idx + 1
    if (idx === 0) return { ...s }
    const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(s.color)
    if (!m) return { ...s } // 非 hex 跳过
    const r = parseInt(m[1], 16) / 255
    const g = parseInt(m[2], 16) / 255
    const b = parseInt(m[3], 16) / 255
    const maxV = Math.max(r, g, b)
    const minV = Math.min(r, g, b)
    const l = (maxV + minV) / 2
    let h = 0, s2 = 0
    if (maxV !== minV) {
      const d = maxV - minV
      s2 = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
      if (maxV === r) h = ((g - b) / d + (g < b ? 6 : 0)) * 60
      else if (maxV === g) h = ((b - r) / d + 2) * 60
      else h = ((r - g) / d + 4) * 60
    }
    const step = 0.2
    const magnitude = Math.ceil(idx / 2) * step
    const direction = idx % 2 === 1 ? 1 : -1
    let newH = h
    let newS = s2
    // 调亮/调暗封顶 [0.3, 0.7],避免太浅/太暗
    let newL = Math.max(0.3, Math.min(0.7, l + direction * magnitude))
    // 阈值 0.30(含 #A0AEC0 这种擦边灰)— 走灰分支更明显
    if (s2 < 0.3) {
      // 灰/低饱和:加饱和 + 偏色相 + L 锁中段 ±10%
      newS = Math.min(0.7, 0.55 + magnitude * 0.3)
      const huePool = [220, 30, 290, 140, 10, 260, 180]
      newH = huePool[(idx - 1) % huePool.length]
      newL = Math.max(0.35, Math.min(0.65, 0.5 + direction * 0.08))
    }
    const c = (1 - Math.abs(2 * newL - 1)) * newS
    const hp = newH / 60
    const x = c * (1 - Math.abs((hp % 2) - 1))
    let r1 = 0, g1 = 0, b1 = 0
    if (hp >= 0 && hp < 1) [r1, g1, b1] = [c, x, 0]
    else if (hp < 2) [r1, g1, b1] = [x, c, 0]
    else if (hp < 3) [r1, g1, b1] = [0, c, x]
    else if (hp < 4) [r1, g1, b1] = [0, x, c]
    else if (hp < 5) [r1, g1, b1] = [x, 0, c]
    else [r1, g1, b1] = [c, 0, x]
    const m2 = newL - c / 2
    const toHex = (n: number) => {
      const v = Math.max(0, Math.min(255, Math.round((n + m2) * 255)))
      return v.toString(16).padStart(2, '0')
    }
    return { ...s, color: `#${toHex(r1)}${toHex(g1)}${toHex(b1)}` }
  })
}

// ========================= 最小可视扇区 =========================
// 对齐 003 React components/DonutChart.tsx MIN_ARC_RATIO 与 007 Flutter
// features/shared/charts/donut_chart.dart minDisplayRatio:2.8% 圆周 ≈ 10°。
//
// 算法核心是 **sqrt 缩放**:raw → sqrt → 归一化。保留顺序 + 拉开小占比之间的差距,
// 让 12% / 9% / 2% / 0.5% 在弧度上肉眼可分,而不是都被顶到同一个 floor。
// MIN_DISPLAY_RATIO 只作为硬底线,sqrt 后还低于它的(0 / 极小值)才顶到 floor。
// legend/tooltip 展示的百分比仍是真实占比,所以信息不丢。
const MIN_DISPLAY_RATIO = 0.028
function computeDisplayRatios(rawRatios: number[]): number[] {
  const n = rawRatios.length
  if (n === 0) return []
  // 第 1 步:sqrt 缩放
  const transformed = rawRatios.map((r) => Math.sqrt(r))
  const sumT = transformed.reduce((a, b) => a + b, 0)
  if (sumT === 0) return rawRatios.map(() => 1 / n)
  let display = transformed.map((t) => t / sumT)
  // 第 2 步:floor 兜底
  display = display.map((d) => d < MIN_DISPLAY_RATIO ? MIN_DISPLAY_RATIO : d)
  // 第 3 步:归一化
  const sumD = display.reduce((a, b) => a + b, 0)
  return display.map((d) => d / sumD)
}

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

// ========================= 共享:H5 SVG + MP/APP-PLUS data URI 都用同一组几何 + 占比计算 =========================
// 把 processedSegments / displayValues / 几何常量挪出 #ifdef,避免 H5 块被 strip 后
// MP 块引用 undefined.value 静默抛错(原 conic-gradient 不渲染就是这个原因)。
const radius = 70
const inner = 40
const cx = 100, cy = 100
const W = 200, H = 200

const processedSegments = computed(() => deduplicateColors(props.segments))

// 最小可视扇区:0.1% / 1% 这种小占比不再被压成一条线。legend/tooltip 中显示的
// 百分比仍是 seg.value / total 的真实比例(displayValue 仅用于画弧 + 浮窗位置)。
const displayValues = computed(() => {
  const segs = processedSegments.value
  if (segs.length === 0) return [] as number[]
  const total = segs.reduce((s, x) => s + x.value, 0) || 1
  const ratios = computeDisplayRatios(segs.map((s) => s.value / total))
  return ratios.map((r) => r * total)
})

// ========================= H5: SVG 实现(直接渲染 <svg>) =========================
// #ifdef H5
const hoverIdx = ref<number | null>(null)
let touchTimer: ReturnType<typeof setTimeout> | null = null

const arcs = computed(() => {
  const segs = processedSegments.value
  const total = segs.reduce((s, x) => s + x.value, 0) || 1
  const values = displayValues.value
  let acc = 0
  return segs.map((s, i) => {
    const start = (acc / total) * Math.PI * 2 - Math.PI / 2
    acc += values[i]
    let end = (acc / total) * Math.PI * 2 - Math.PI / 2
    if (segs.length === 1) {
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
      pct: ((s.value / total) * 100).toFixed(2),
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

// ========================= MP/APP-PLUS: SVG → data URI → <image> =========================
// #ifdef MP-WEIXIN || APP-PLUS
//
// 思路:跟 LineChart 一样 — 把跟 H5 完全相同的 SVG 字符串 encodeURIComponent 编码后,
// 塞到 <image src="data:image/svg+xml;charset=utf-8,...">。
//
// 原版用 conic-gradient,实测在 Android APP-PLUS webview 上不渲染(中心文字在但
// ring 是白的 — :style 里的 background/conic-gradient 被解析后丢了),iOS APP-PLUS
// 同问题。改成 SVG data URI 跟 LineChart 对齐,mp 基础库 ≥ 2.10.0 / 原生 webview 都吃。
//
// 几何参数:viewBox 200x200,ring 外半径 70 内半径 40。<image> 跟 stack 一起
// 100% 自适应(stack = width:100% + padding-bottom:100% → 正方形;viewBox 1:1 →
// 不变形),实际显示尺寸 = 容器宽 = 卡片宽。触摸判定内外径按 SVG 几何
// (radius/W, inner/W) 比例缩放,不写死像素(老版本写死 320rpx 在大屏上视觉
// 比 H5 小一大圈)。

const svgDataUri = computed(() => {
  const segs = processedSegments.value
  if (segs.length === 0) return ''
  const total = segs.reduce((s, x) => s + x.value, 0) || 1
  const values = displayValues.value
  let acc = 0
  let paths = ''
  for (let i = 0; i < segs.length; i++) {
    const s = segs[i]
    const start = (acc / total) * Math.PI * 2 - Math.PI / 2
    acc += values[i]
    let end = (acc / total) * Math.PI * 2 - Math.PI / 2
    if (segs.length === 1) end = start + Math.PI * 2 - 0.001
    const large = end - start > Math.PI ? 1 : 0
    const x1 = cx + radius * Math.cos(start), y1 = cy + radius * Math.sin(start)
    const x2 = cx + radius * Math.cos(end),   y2 = cy + radius * Math.sin(end)
    const ix1 = cx + inner * Math.cos(end),   iy1 = cy + inner * Math.sin(end)
    const ix2 = cx + inner * Math.cos(start), iy2 = cy + inner * Math.sin(start)
    paths += `<path d="M ${x1} ${y1} A ${radius} ${radius} 0 ${large} 1 ${x2} ${y2} L ${ix1} ${iy1} A ${inner} ${inner} 0 ${large} 0 ${ix2} ${iy2} Z" fill="${s.color}"/>`
  }
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid meet">${paths}</svg>`
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg)
})

// MP 点击浮窗:<image> 是静态图,SVG 元素不可交互 → 透明覆盖层捕获触摸位置
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
    // 查 .mp-donut-stack 而不是 .mp-donut-image:<image> 在 APP-PLUS 上
    // boundingClientRect 偶尔拿不到真实尺寸,stack 才是稳定带尺寸的容器
    q.select('.mp-donut-stack').boundingClientRect()
    q.exec((res: any) => resolve((res && res[0]) || null))
  })
}

// 几何(对齐 SVG viewBox,按 size 比例缩放 — 不写死像素,响应式尺寸都能算对):
// viewBox 200×200,ring 外半径 70、内半径 40。触摸判定的内外径 =
//(radius/W, inner/W) × size = (0.35, 0.20) × size。
function findSegmentAt(localX: number, localY: number, size: number): number | null {
  if (processedSegments.value.length === 0) return null
  const cx = size / 2
  const cy = size / 2
  const rOuter = (radius / W) * size
  const rInner = (inner / W) * size
  const dx = localX - cx
  const dy = localY - cy
  const dist = Math.hypot(dx, dy)
  if (dist < rInner || dist > rOuter) return null
  // atan2 → 数学角(0 = 3 点钟,逆时针为正);转成 conic 角(0 = 12 点钟,顺时针为正)
  let deg = Math.atan2(dy, dx) * 180 / Math.PI + 90
  if (deg < 0) deg += 360
  if (deg >= 360) deg -= 1e-6
  const total = processedSegments.value.reduce((s, x) => s + x.value, 0) || 1
  const values = displayValues.value
  let acc = 0
  for (let i = 0; i < processedSegments.value.length; i++) {
    const startDeg = (acc / total) * 360
    acc += values[i]
    const endDeg = (acc / total) * 360
    if (deg >= startDeg && deg < endDeg) return i
  }
  return processedSegments.value.length - 1
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
    // 浮窗位置:命中 segment 的中线角,往外挪 12 viewBox 单位(对齐 H5 seg-tip)。
    // 用 displayValues(而非 raw value)算中线角,保证指向可见弧中心。
    const total = processedSegments.value.reduce((s, x) => s + x.value, 0) || 1
    const values = displayValues.value
    let acc = 0
    for (let i = 0; i < idx; i++) acc += values[i]
    const startDeg = (acc / total) * 360
    const endDeg = ((acc + values[idx]) / total) * 360
    const midDeg = (startDeg + endDeg) / 2
    const midRad = (midDeg - 90) * Math.PI / 180
    const tipR = ((radius + 12) / W) * rect.width  // 12 viewBox 单位 = 6% × size past outer
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
  return processedSegments.value[idx] ?? null
})
const mpTipPct = computed(() => {
  const seg = mpTipSeg.value
  if (!seg) return '0.00'
  const total = processedSegments.value.reduce((s, x) => s + x.value, 0) || 1
  return ((seg.value / total) * 100).toFixed(2)
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

    <!-- MP/APP-PLUS: SVG data URI → <image>(照 LineChart 模式;原 conic-gradient 在 Android/iOS webview 上不渲染) -->
    <!-- #ifdef MP-WEIXIN || APP-PLUS -->
    <view class="mp-donut-wrap">
      <view class="mp-donut-stack">
        <image v-if="svgDataUri" :src="svgDataUri" class="mp-donut-image" />
        <!-- 中心文字覆盖在 <image> 上,与原 conic 方案视觉对齐 -->
        <view class="mp-donut-center">
          <text class="mp-donut-label">{{ finalTotalLabel }}</text>
          <text class="mp-donut-total">{{ totalValue }}</text>
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

/* MP: SVG data URI → <image> 环图(对齐 LineChart + H5 视觉) */
/* 关键点:stack 用 width:100% + padding-bottom:100% 自适应成卡片宽度的正方形,
   <image> 跟 stack 一起 100% 撑满;viewBox 1:1 + container 1:1 → 无变形。
   不要写死 rpx — 之前写 320rpx 在大屏上环图只占卡片中间一小块,跟 H5 不一致。 */
.mp-donut-wrap {
  width: 100%;
  position: relative;
}
.mp-donut-stack {
  position: relative;
  width: 100%;
  height: 0;
  padding-bottom: 100%;  /* 正方形:高 = 宽,跟 H5 donut-wrap 完全一致的 trick */
  margin: 0 auto;
}
.mp-donut-image {
  position: absolute;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  display: block;
}
/* 中心文字覆盖在 <image> 上 — 跟 H5 一样走 SVG 透明内圈,白卡背景自然透出,
   不要画白色 circle overlay 盖住(比例容易跟 SVG hole 对不齐)。 */
.mp-donut-center {
  position: absolute;
  left: 0;
  top: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  pointer-events: none;
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
