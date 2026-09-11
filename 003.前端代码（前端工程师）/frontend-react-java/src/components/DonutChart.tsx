import { useMemo, useRef, useState } from 'react'
import { useLanguage } from '../i18n/LanguageContext'
import { deduplicateColors } from '../lib/chart-color'

export interface DonutSegment {
  label: string
  value: number
  color: string
}

/** 最小可视弧度:2.8% 圆周 ≈ 10°。
 * 作为硬底线 — sqrt 缩放后仍低于此值的扇区(如 0% / 极小值)才会被顶到 MIN_ARC,
 * 保证肉眼可见、可点击;再归一化让 sum = 1。
 *
 * 算法核心是 **sqrt 缩放**:
 *   raw = [51%, 25.5%, 12%, 9%, 2%, 0.5%] →
 *   sqrt = [71.4%, 50.5%, 34.5%, 30.2%, 14.1%, 7.07%]
 *   normalized → [34.4%, 24.3%, 16.6%, 14.5%, 6.8%, 3.4%]
 *
 * sqrt 同时保留大小顺序 + 拉开小占比之间的差距,
 * 让 12% / 9% / 2% / 0.5% 在弧度上肉眼可分,而不是都被压扁或都顶到同一个 floor。
 * legend/tooltip 中展示的百分比仍是真实比例,所以信息不丢。 */
export const MIN_ARC_RATIO = 0.028

/** 给一组 rawRatio(总和应为 1),返回调整后的 displayRatio。
 * - sqrt 缩放保留顺序、放大小占比差异
 * - floor 保证 0 / 极小值仍可见
 * - 归一化保证 sum = 1 */
export function computeDisplayRatios(rawRatios: readonly number[]): number[] {
  const n = rawRatios.length
  if (n === 0) return []
  // 第 1 步:sqrt 缩放
  const transformed = rawRatios.map((r) => Math.sqrt(r))
  const sumT = transformed.reduce((a, b) => a + b, 0)
  if (sumT === 0) return rawRatios.map(() => 1 / n)
  let display = transformed.map((t) => t / sumT)
  // 第 2 步:floor 兜底
  display = display.map((d) => Math.max(d, MIN_ARC_RATIO))
  // 第 3 步:归一化
  const sumD = display.reduce((a, b) => a + b, 0)
  return display.map((d) => d / sumD)
}

interface DonutChartProps {
  segments: DonutSegment[]
  totalLabelKey?: string
  totalLabel?: string
  totalValue: string
}

interface SegmentGeom {
  /** 该段长度(用于在 stroke-dasharray 上精确绘制) */
  length: number
  /** tooltip 锚点 X(百分比,相对 SVG viewBox) */
  tipX: number
  /** tooltip 锚点 Y(百分比) */
  tipY: number
}

/**
 * 收入/支出占比环形图(纯 SVG + 触摸/鼠标交互)
 * - segments 按 value 排序后顺时针排列
 * - 中心展示 totalLabel + totalValue
 * - 悬停 / 触摸扇区:加大描边宽度 + 其它扇区降低透明度 + 弹出分类 tooltip
 * - 内嵌 legend:点击 / 触摸行 → 联动高亮扇区(避免在窄弧上点不准)
 */
export function DonutChart({
  segments,
  totalLabelKey = 'chart.donutTotal',
  totalLabel,
  totalValue,
}: DonutChartProps) {
  const { t } = useLanguage()
  const finalTotalLabel = totalLabel ?? t(totalLabelKey)
  const size = 220
  const stroke = 30
  const radius = (size - stroke) / 2
  const cx = size / 2
  const cy = size / 2
  const circumference = 2 * Math.PI * radius
  const svgRef = useRef<SVGSVGElement>(null)
  const [hoverIdx, setHoverIdx] = useState<number | null>(null)
  const touchTimerRef = useRef<number | null>(null)

  // 防撞色:同一图表内 hex 重复时挨个调亮/调暗阶梯 ±20%。
  // 顺序保持,donut/ranking/legend 视觉一致;ranking 进度条用的是原始 colorHex
  // (在 ReportMonthly 那边),所以这里改的是 donut 渲染色,不破坏 ranking。
  const processedSegments = useMemo(() => deduplicateColors(segments), [segments])
  const total = processedSegments.reduce((s, x) => s + x.value, 0) || 1

  // 每个扇区最小可视弧度:0.1% / 1% 这种小占比不再被压成一条线,
  // legend/tooltip 中显示的百分比仍是真实比例。
  const displayRatios = useMemo(
    () => computeDisplayRatios(processedSegments.map((s) => s.value / total)),
    [processedSegments, total],
  )

  // 计算每段 tooltip 锚点(圆环外侧),用百分比定位便于随容器缩放
  const geoms = useMemo<SegmentGeom[]>(() => {
    let cursor = 0
    const tipR = radius + stroke / 2 + 14
    return processedSegments.map((seg, i) => {
      const length = displayRatios[i] * circumference
      const midLen = cursor + length / 2
      const angle = (midLen / circumference) * 2 * Math.PI
      const visualAngle = angle - Math.PI / 2
      const tipX = ((cx + Math.cos(visualAngle) * tipR) / size) * 100
      const tipY = ((cy + Math.sin(visualAngle) * tipR) / size) * 100
      cursor += length
      return { length, tipX, tipY }
    })
  }, [processedSegments, displayRatios, radius, stroke, cx, cy, circumference, size])

  function clearTouchTimer() {
    if (touchTimerRef.current !== null) {
      window.clearTimeout(touchTimerRef.current)
      touchTimerRef.current = null
    }
  }

  function onTouchStart(i: number, e: React.TouchEvent | React.MouseEvent) {
    if ('preventDefault' in e) e.preventDefault()
    clearTouchTimer()
    setHoverIdx(i)
    // 触摸后保持 2s 显示
    touchTimerRef.current = window.setTimeout(() => {
      setHoverIdx(null)
      touchTimerRef.current = null
    }, 2000)
  }

  let offset = 0
  return (
    <div className="flex flex-col items-center gap-2">
      {/* SVG 圆环 */}
      <div className="relative inline-block">
        <svg
          ref={svgRef}
          viewBox={`0 0 ${size} ${size}`}
          className="w-full max-w-[220px] h-auto select-none"
          preserveAspectRatio="xMidYMid meet"
        >
          {/* 背景圈 */}
          <circle
            cx={cx}
            cy={cy}
            r={radius}
            fill="none"
            stroke="#F1F5F9"
            strokeWidth={stroke}
          />
          <g transform={`rotate(-90 ${cx} ${cy})`}>
            {processedSegments.map((seg, i) => {
              const length = displayRatios[i] * circumference
              const dashArray = `${length} ${circumference - length}`
              const dashOffset = -offset
              offset += length
              const isHover = hoverIdx === i
              const dimmed = hoverIdx !== null && !isHover
              return (
                <g key={i}>
                  {/* 透明命中层(更宽的描边,方便触摸/悬停;hit 区比可见弧宽 22px) */}
                  <circle
                    cx={cx}
                    cy={cy}
                    r={radius}
                    fill="none"
                    stroke={seg.color}
                    strokeWidth={stroke + 22}
                    strokeDasharray={dashArray}
                    strokeDashoffset={dashOffset}
                    opacity={0}
                    style={{ cursor: 'pointer', pointerEvents: 'stroke' }}
                    onMouseEnter={() => setHoverIdx(i)}
                    onMouseLeave={() => setHoverIdx(null)}
                    onTouchStart={(e) => onTouchStart(i, e)}
                  />
                  {/* 可见扇区 */}
                  <circle
                    cx={cx}
                    cy={cy}
                    r={radius}
                    fill="none"
                    stroke={seg.color}
                    strokeWidth={isHover ? stroke + 4 : stroke}
                    strokeDasharray={dashArray}
                    strokeDashoffset={dashOffset}
                    strokeLinecap="butt"
                    pointerEvents="none"
                    style={{
                      transition: 'stroke-width 0.15s ease-out, opacity 0.15s ease-out',
                      opacity: dimmed ? 0.35 : 1,
                    }}
                  />
                </g>
              )
            })}
          </g>
        </svg>

        {/* 中心文字 */}
        <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
          <span className="font-caption-sm text-caption-sm text-on-surface-variant">
            {finalTotalLabel}
          </span>
          <span className="font-label-mono text-label-mono text-text-primary text-xl font-bold">
            {totalValue}
          </span>
        </div>

        {/* 扇区 tooltip */}
        {hoverIdx !== null && geoms[hoverIdx] && (
          <div
            className="absolute pointer-events-none z-10 bg-bg-card border border-divider rounded-lg shadow-lg px-3 py-2 min-w-[130px] -translate-x-1/2 -translate-y-1/2"
            style={{
              left: `${geoms[hoverIdx].tipX}%`,
              top: `${geoms[hoverIdx].tipY}%`,
            }}
          >
            <div className="flex items-center gap-2 mb-1">
              <span
                className="inline-block w-3 h-3 rounded-sm flex-shrink-0"
                style={{ background: processedSegments[hoverIdx].color }}
              />
              <span className="text-xs font-bold text-text-primary">
                {processedSegments[hoverIdx].label}
              </span>
            </div>
            <div className="text-sm font-semibold text-text-primary">
              ¥{processedSegments[hoverIdx].value.toLocaleString('zh-CN', { maximumFractionDigits: 0 })}
            </div>
            <div className="text-xs text-on-surface-variant">
              {((processedSegments[hoverIdx].value / total) * 100).toFixed(2)}%
            </div>
          </div>
        )}
      </div>

      {/* 内嵌 legend:色块 + 名称 + 百分比,点行 → 联动扇区高亮。
          不设 max-height:有数据就往下平铺,卡片随内容一起增长(由父容器去掉 h-[480px])。 */}
      <div className="w-full pr-1 space-y-1">
        {processedSegments.map((seg, i) => {
          const pct = (seg.value / total) * 100
          const isHover = hoverIdx === i
          return (
            <button
              key={i}
              type="button"
              className={`w-full flex items-center gap-2 px-2 py-1.5 rounded-md text-left transition-colors ${
                isHover ? 'bg-primary-soft' : 'hover:bg-surface-container'
              }`}
              onMouseEnter={() => setHoverIdx(i)}
              onMouseLeave={() => setHoverIdx(null)}
              onTouchStart={(e) => onTouchStart(i, e)}
              onFocus={() => setHoverIdx(i)}
              onBlur={() => setHoverIdx(null)}
            >
              <span
                className="inline-block w-2.5 h-2.5 rounded-sm flex-shrink-0"
                style={{ background: seg.color }}
              />
              <span className="flex-1 min-w-0 truncate font-caption-sm text-caption-sm text-text-primary">
                {seg.label}
              </span>
              <span className="flex-shrink-0 font-caption-sm text-caption-sm font-semibold text-text-primary tabular-nums">
                {pct.toFixed(2)}%
              </span>
            </button>
          )
        })}
      </div>
    </div>
  )
}