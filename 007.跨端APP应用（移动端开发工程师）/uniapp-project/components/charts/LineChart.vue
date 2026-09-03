<script setup lang="ts">
import { computed, ref, watch, getCurrentInstance } from 'vue'
import { useLanguage } from '@/i18n/useLanguage'

// 每日收支曲线。H5 走 SVG(浏览器原生支持),MP 走 SVG → data URI → <image>
//(基础库 2.10.0+ 原生支持 SVG 图片;完全绕开 vue3 mp 编译器对 <canvas> 的处理)。
//
// 对外接口不变(:data / :smoothWindow / incomeColor / expenseColor),
// monthly.vue 不需要改。

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

const YMAX = 4000
const { t } = useLanguage()

// ========================= H5: SVG 实现(完全保留原逻辑) =========================
// #ifdef H5
const W = 800, H = 320
const PAD = { top: 20, right: 20, bottom: 40, left: 50 }
const innerW = W - PAD.left - PAD.right
const innerH = H - PAD.top - PAD.bottom

const hover = ref<{ idx: number; localX: number } | null>(null)
const svgEl = ref<any>(null)

function smooth(values: number[], w: number): number[] {
  if (w <= 1) return values
  return values.map((_, i) => {
    const start = Math.max(0, i - w + 1)
    const slice = values.slice(start, i + 1)
    return slice.reduce((s, v) => s + v, 0) / slice.length
  })
}

const xs = computed(() => props.data.map((_, i) => PAD.left + (i / Math.max(1, props.data.length - 1)) * innerW))
const ysF = (v: number) => PAD.top + innerH - (v / YMAX) * innerH

function smoothPath(values: number[]): string {
  if (values.length === 0) return ''
  const pts = values.map((v, i) => ({ x: xs.value[i], y: ysF(v) }))
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
const incomeArea = computed(() => {
  if (props.data.length === 0) return ''
  const first = xs.value[0]
  const last = xs.value[xs.value.length - 1]
  return lineIncome.value + ` L ${last},${ysF(0)} L ${first},${ysF(0)} Z`
})

const yTicks = [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000]
const xTicks = [1, 5, 10, 15, 20, 25, 30]

function pickIdx(clientX: number): number | null {
  const svg = svgEl.value
  if (!svg) return null
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
  const rect = svg.getBoundingClientRect()
  hover.value = { idx, localX: offsetX - rect.left }
}
function onTouchEnd() {
  setTimeout(() => { hover.value = null }, 1500)
}
function clearHover() { hover.value = null }

const hoverData = computed(() => hover.value ? props.data[hover.value.idx] : null)
const hoverVbX = computed(() => hover.value ? xs.value[hover.value.idx] : 0)
const hoverTopPct = computed(() => {
  if (!hoverData.value || !hover.value) return '50%'
  const yVal = Math.max(hoverData.value.income, hoverData.value.expense)
  return `${(ysF(Math.min(yVal, YMAX)) / H) * 100}%`
})
const tipAnchor = computed(() => {
  if (!hover.value || !svgEl.value) return 'center'
  const rect = svgEl.value.getBoundingClientRect()
  const ratio = hover.value.localX / rect.width
  // 贴左(<20%)→ tip 往右偏,避开 Y 轴标签;贴右(>80%)→ tip 往左偏,避免溢出
  if (ratio < 0.2) return 'left'
  if (ratio > 0.8) return 'right'
  return 'center'
})
// #endif

// ========================= MP/APP-PLUS: SVG → data URI → <image> =========================
// #ifdef MP-WEIXIN || APP-PLUS
//
// 思路:把跟 H5 完全一样的 SVG 字符串用 encodeURIComponent 编码后,
// 塞到 <image src="data:image/svg+xml;charset=utf-8,...">。mp 基础库 ≥ 2.10.0
// 原生支持 SVG 图片(<image> 是 mp 原生组件,不受 vue3 mp 编译 canvas 渲染 bug 影响)。
//
// 视觉跟 H5 一模一样(因为是同一份 SVG)。

const MP_W = 800
const MP_H = 320
const MP_PAD = { top: 20, right: 20, bottom: 40, left: 50 }
const MP_INNER_W = MP_W - MP_PAD.left - MP_PAD.right
const MP_INNER_H = MP_H - MP_PAD.top - MP_PAD.bottom

function smoothArr(values: number[], w: number): number[] {
  if (w <= 1) return values
  return values.map((_, i) => {
    const start = Math.max(0, i - w + 1)
    const slice = values.slice(start, i + 1)
    return slice.reduce((s, v) => s + v, 0) / slice.length
  })
}

// X 坐标(viewBox 单位),抽出来供 SVG 生成 + tooltip 定位复用
function getMpXs(): number[] {
  return props.data.map((_, i) =>
    MP_PAD.left + (i / Math.max(1, props.data.length - 1)) * MP_INNER_W
  )
}
const ysMp = (v: number) => MP_PAD.top + MP_INNER_H - (v / YMAX) * MP_INNER_H

function mpSmoothPath(values: number[], xsMp: number[]): string {
  if (values.length === 0) return ''
  const pts = values.map((v, i) => ({ x: xsMp[i], y: ysMp(v) }))
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

function escXml(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

const svgDataUri = computed(() => {
  if (props.data.length === 0) return ''
  const xsMp = getMpXs()

  const incomeSm = smoothArr(props.data.map(d => d.income), props.smoothWindow)
  const expenseSm = smoothArr(props.data.map(d => d.expense), props.smoothWindow)
  const incomePath = mpSmoothPath(incomeSm.map(v => Math.min(v, YMAX)), xsMp)
  const expensePath = mpSmoothPath(expenseSm.map(v => Math.min(v, YMAX)), xsMp)
  const areaPath = incomePath + ` L ${xsMp[xsMp.length - 1]},${ysMp(0)} L ${xsMp[0]},${ysMp(0)} Z`

  // Y 轴网格 + 标签
  const gridLines = [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000].map(v => {
    const y = ysMp(v)
    return `<line x1="${MP_PAD.left}" x2="${MP_W - MP_PAD.right}" y1="${y}" y2="${y}" stroke="#E2E8F0" stroke-width="1" />` +
      `<text x="${MP_PAD.left - 4}" y="${y}" font-size="11" fill="#64748b" text-anchor="end" dominant-baseline="middle">${v.toLocaleString('en-US')}</text>`
  }).join('')

  // X 轴标签(1/5/10/15/20/25/30)
  const xLabels = [1, 5, 10, 15, 20, 25, 30].map(d => {
    if (d < 1 || d > props.data.length) return ''
    return `<text x="${xsMp[d - 1]}" y="${MP_H - MP_PAD.bottom + 18}" font-size="11" fill="#64748b" text-anchor="middle">${d}</text>`
  }).join('')

  const svg =
    `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${MP_W} ${MP_H}" preserveAspectRatio="xMidYMid meet">` +
    gridLines +
    `<path d="${areaPath}" fill="${escXml(props.incomeColor)}" fill-opacity="0.1" />` +
    `<path d="${incomePath}" stroke="${escXml(props.incomeColor)}" stroke-width="2" fill="none" stroke-linejoin="round" stroke-linecap="round" />` +
    `<path d="${expensePath}" stroke="${escXml(props.expenseColor)}" stroke-width="2" fill="none" stroke-linejoin="round" stroke-linecap="round" />` +
    xLabels +
    `</svg>`

  // mp <image> 支持 data:image/svg+xml;charset=utf-8,...(直接 utf8 字符串,无需 base64)
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg)
})

// MP 点击浮窗(<image> 是静态图,SVG 元素不可交互 → 透明 <view> 捕获触摸位置 → 算最近数据点)
// H5 直接在 SVG 内画 dashed line + 圆点 + tooltip;<image> 路线做不到内嵌元素,
// 但浮窗(数据信息)是用户最在意的,UX 等价。
const mpTooltipIdx = ref<number | null>(null)
const mpTipLeftPct = ref('50%')    // 相对图表框宽度百分比
const mpTipTopPct = ref('50%')     // 相对图表框高度百分比
const mpTipAnchor = ref<'left' | 'right'>('left') // 贴边时翻转
let mpTipTimer: ReturnType<typeof setTimeout> | null = null
const ins = getCurrentInstance()

function queryRect(): Promise<{ left: number; top: number; width: number; height: number } | null> {
  return new Promise((resolve) => {
    // #ifdef MP-WEIXIN || APP-PLUS
    const q = uni.createSelectorQuery().in(ins)
    q.select('.mp-line-image').boundingClientRect()
    q.exec((res: any) => {
      resolve((res && res[0]) || null)
    })
    // #endif
  })
}

function onMpTouch(e: any) {
  // MP @touchstart 坐标字段不统一,逐级兜底
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
  queryRect().then((rect) => {
    if (!rect || rect.width === 0 || props.data.length === 0) return
    const localX = x! - rect.left
    const localY = y! - rect.top
    if (localX < 0 || localX > rect.width || localY < 0 || localY > rect.height) return
    const vbX = (localX / rect.width) * MP_W
    // 落在绘图区内才命中(忽略边距)
    if (vbX < MP_PAD.left || vbX > MP_W - MP_PAD.right) return
    const ratio = (vbX - MP_PAD.left) / MP_INNER_W
    const dayIdx = Math.round(ratio * (props.data.length - 1))
    const idx = Math.max(0, Math.min(props.data.length - 1, dayIdx))
    const xsMp = getMpXs()
    // 浮窗水平:数据点 X(居中)
    mpTipLeftPct.value = `${(xsMp[idx] / MP_W) * 100}%`
    // 浮窗垂直:取当日 income/expense 中较大值的 Y(浮窗显示在曲线点上方)
    const day = props.data[idx]
    const topYVal = Math.max(day.income, day.expense)
    const vbY = ysMp(Math.min(topYVal, YMAX))
    mpTipTopPct.value = `${(vbY / MP_H) * 100}%`
    // 贴边翻转:贴左(<20%)→ tip 往右偏(避开 Y 轴标签);贴右(>80%)→ tip 往左偏(避免溢出)
    mpTipAnchor.value = localX < rect.width * 0.2 ? 'left'
                     : localX > rect.width * 0.8 ? 'right'
                     : 'center'
    mpTooltipIdx.value = idx
    if (mpTipTimer) clearTimeout(mpTipTimer)
    mpTipTimer = setTimeout(() => {
      mpTooltipIdx.value = null
      mpTipTimer = null
    }, 1800)
  })
}

function onMpTouchEnd() {
  // 计时器已在 onMpTouch 里启动,这里不重置(让浮窗停留 1.8s)
}

const mpTooltipDay = computed(() => {
  const idx = mpTooltipIdx.value
  if (idx === null) return 0
  const p = props.data[idx]
  return p ? p.day : 0
})
const mpTooltipIncome = computed(() => {
  const idx = mpTooltipIdx.value
  if (idx === null) return 0
  const p = props.data[idx]
  return p ? p.income : 0
})
const mpTooltipExpense = computed(() => {
  const idx = mpTooltipIdx.value
  if (idx === null) return 0
  const p = props.data[idx]
  return p ? p.expense : 0
})

// 数据源切换时清掉 tooltip(否则 idx 仍指向旧数组越界位置)
watch(() => props.data, () => {
  mpTooltipIdx.value = null
  if (mpTipTimer) { clearTimeout(mpTipTimer); mpTipTimer = null }
})
// #endif
</script>

<template>
  <view class="line-wrap">
    <!-- H5: 原 SVG 实现 -->
    <!-- #ifdef H5 -->
    <svg ref="svgEl" :viewBox="`0 0 ${W} ${H}`" preserveAspectRatio="xMidYMid meet"
         @touchstart="onTouch" @touchmove="onTouch" @touchend="onTouchEnd">
      <g v-for="v in yTicks" :key="v">
        <line :x1="PAD.left" :x2="W - PAD.right" :y1="ysF(v)" :y2="ysF(v)"
              stroke="#E2E8F0" stroke-width="1" />
      </g>
      <path :d="incomeArea" :fill="incomeColor" fill-opacity="0.1" />
      <path :d="lineIncome" :stroke="incomeColor" fill="none"
            stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
      <path :d="lineExpense" :stroke="expenseColor" fill="none"
            stroke-width="2" stroke-linejoin="round" stroke-linecap="round" />
      <line v-if="hover" :x1="hoverVbX" :x2="hoverVbX"
            :y1="PAD.top" :y2="H - PAD.bottom"
            stroke="#94a3b8" stroke-width="1" stroke-dasharray="3 3" />
      <template v-if="hoverData">
        <circle :cx="hoverVbX" :cy="ysF(Math.min(hoverData.income, YMAX))" r="5"
                fill="#fff" :stroke="incomeColor" stroke-width="2" />
        <circle :cx="hoverVbX" :cy="ysF(Math.min(hoverData.expense, YMAX))" r="5"
                fill="#fff" :stroke="expenseColor" stroke-width="2" />
      </template>
    </svg>
    <text v-for="v in yTicks" :key="`y-${v}`" class="axis-y"
          :style="{ left: (PAD.left / W * 100) + '%', top: (ysF(v) / H * 100) + '%' }">
      {{ v.toLocaleString('en-US') }}
    </text>
    <text v-for="d in xTicks" :key="`x-${d}`" class="axis-x"
          :style="{ left: (xs[d - 1] / W * 100) + '%', top: ((H - PAD.bottom + 18) / H * 100) + '%' }">
      {{ d }}
    </text>
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
    <!-- #endif -->

    <!-- MP/APP-PLUS: SVG → data URI → <image>(mp 基础库 ≥ 2.10.0 / 原生 webview 都吃) -->
    <!-- #ifdef MP-WEIXIN || APP-PLUS -->
    <view class="mp-line-frame">
      <image v-if="svgDataUri" :src="svgDataUri" mode="widthFix" class="mp-line-image" />
      <!-- 透明覆盖层:捕获点击/拖动位置,计算最近数据点 -->
      <view class="mp-touch-layer"
            @touchstart="onMpTouch"
            @touchmove="onMpTouch"
            @touchend="onMpTouchEnd"
            @touchcancel="onMpTouchEnd" />
      <!-- 浮窗:对齐 H5 tip 的内容(日期 + 收入 + 支出) -->
      <view v-if="mpTooltipIdx !== null"
            class="mp-tip"
            :class="`mp-tip-${mpTipAnchor}`"
            :style="{ left: mpTipLeftPct, top: mpTipTopPct }">
        <view class="mp-tip-day">{{ mpTooltipDay }}</view>
        <view class="mp-tip-row">
          <view class="mp-tip-swatch" :style="{ borderColor: incomeColor }" />
          <text class="mp-tip-text">{{ t('chart.line.income') }}: {{ Math.round(mpTooltipIncome).toLocaleString('en-US') }}</text>
        </view>
        <view class="mp-tip-row">
          <view class="mp-tip-swatch" :style="{ borderColor: expenseColor }" />
          <text class="mp-tip-text">{{ t('chart.line.expense') }}: {{ Math.round(mpTooltipExpense).toLocaleString('en-US') }}</text>
        </view>
      </view>
    </view>
    <!-- #endif -->
  </view>
</template>

<style scoped>
.line-wrap { position: relative; width: 100%; }
svg { width: 100%; height: auto; display: block; }
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
  white-space: nowrap;
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
.tip-left  { transform: translate(0,      -110%); }
.tip-day { font-weight: 700; font-size: 24rpx; margin-bottom: 4rpx; color: var(--c-text); }
.tip-row { display: flex; align-items: center; gap: 8rpx; margin-top: 4rpx; }
.tip-swatch { width: 10rpx; height: 10rpx; background: transparent; border: 2rpx solid; border-radius: 2rpx; }
.tip-text { font-size: 22rpx; color: var(--c-text); }
/* MP: <image> 显示 SVG(按宽度自适应,viewBox 800x320 → 高度 = width * 320/800) */
.line-image { width: 100%; display: block; }

/* MP: 图表框 + 触摸覆盖层 + 浮窗 */
.mp-line-frame { position: relative; width: 100%; }
.mp-line-image { display: block; width: 100%; }
.mp-touch-layer {
  position: absolute; left: 0; top: 0; width: 100%; height: 100%;
  /* rgba(0,0,0,0.001) 而非 transparent:mp 上某些版本 transparent 不产生 hit area */
  background: rgba(0, 0, 0, 0.001);
  z-index: 2;
}
.mp-tip {
  position: absolute;
  transform: translate(-50%, calc(-100% - 12rpx));
  background: var(--c-bg-card);
  border: 1px solid var(--c-divider);
  border-radius: 12rpx;
  padding: 12rpx 18rpx;
  font-size: 22rpx;
  color: var(--c-text);
  box-shadow: 0 4rpx 16rpx rgba(0, 0, 0, 0.12);
  pointer-events: none;
  min-width: 180rpx;
  z-index: 10;
}
/* 贴边翻转:右侧时浮窗往左偏,左侧时往右偏 */
.mp-tip-right { transform: translate(-100%, calc(-100% - 12rpx)); }
.mp-tip-left  { transform: translate(0,      calc(-100% - 12rpx)); }
.mp-tip-day { font-weight: 700; font-size: 24rpx; color: var(--c-text); margin-bottom: 6rpx; }
.mp-tip-row { display: flex; align-items: center; gap: 10rpx; margin-top: 6rpx; }
.mp-tip-swatch {
  width: 12rpx; height: 12rpx;
  background: transparent;
  border: 2rpx solid;
  border-radius: 4rpx;
}
.mp-tip-text { font-size: 22rpx; color: var(--c-text); }
</style>
