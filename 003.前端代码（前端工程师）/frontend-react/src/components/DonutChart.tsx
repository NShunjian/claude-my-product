import { useMemo, useRef, useState } from 'react'

export interface DonutSegment {
  label: string
  value: number
  color: string
}

interface DonutChartProps {
  segments: DonutSegment[]
  totalLabel?: string
  totalValue: string
}

interface SegmentGeom {
  /** 该段长度（用于在 stroke-dasharray 上精确绘制） */
  length: number
  /** tooltip 锚点 X（百分比，相对 SVG viewBox） */
  tipX: number
  /** tooltip 锚点 Y（百分比） */
  tipY: number
}

/**
 * 支出占比环形图（纯 SVG + 触摸/鼠标交互）
 * - segments 按 value 排序后顺时针排列
 * - 中心展示 totalLabel + totalValue
 * - 悬停 / 触摸扇区：放大描边宽度 + 弹出分类 tooltip
 */
export function DonutChart({
  segments,
  totalLabel = '总计',
  totalValue,
}: DonutChartProps) {
  const size = 280
  const stroke = 36
  const radius = (size - stroke) / 2
  const cx = size / 2
  const cy = size / 2
  const circumference = 2 * Math.PI * radius
  const svgRef = useRef<SVGSVGElement>(null)
  const [hoverIdx, setHoverIdx] = useState<number | null>(null)
  const touchTimerRef = useRef<number | null>(null)

  const total = segments.reduce((s, x) => s + x.value, 0) || 1

  // 计算每段 tooltip 锚点（圆环外侧），用百分比定位便于随容器缩放
  const geoms = useMemo<SegmentGeom[]>(() => {
    let cursor = 0
    const tipR = radius + stroke / 2 + 18
    return segments.map((seg) => {
      const length = (seg.value / total) * circumference
      const midLen = cursor + length / 2
      const angle = (midLen / circumference) * 2 * Math.PI
      const visualAngle = angle - Math.PI / 2
      const tipX = ((cx + Math.cos(visualAngle) * tipR) / size) * 100
      const tipY = ((cy + Math.sin(visualAngle) * tipR) / size) * 100
      cursor += length
      return { length, tipX, tipY }
    })
  }, [segments, total, radius, stroke, cx, cy, circumference, size])

  function clearTouchTimer() {
    if (touchTimerRef.current !== null) {
      window.clearTimeout(touchTimerRef.current)
      touchTimerRef.current = null
    }
  }

  function onTouchStart(i: number, e: React.TouchEvent) {
    e.preventDefault()
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
    <div className="relative inline-block">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${size} ${size}`}
        className="w-full max-w-[280px] h-auto select-none"
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
          {segments.map((seg, i) => {
            const length = (seg.value / total) * circumference
            const dashArray = `${length} ${circumference - length}`
            const dashOffset = -offset
            offset += length
            const isHover = hoverIdx === i
            return (
              <g key={i}>
                {/* 透明命中层（更宽的描边，方便触摸/悬停） */}
                <circle
                  cx={cx}
                  cy={cy}
                  r={radius}
                  fill="none"
                  stroke={seg.color}
                  strokeWidth={stroke + 18}
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
                  style={{ transition: 'stroke-width 0.15s ease-out' }}
                />
              </g>
            )
          })}
        </g>
      </svg>

      {/* 中心文字 */}
      <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
        <span className="font-caption-sm text-caption-sm text-on-surface-variant">
          {totalLabel}
        </span>
        <span className="font-label-mono text-label-mono text-text-primary text-2xl font-bold">
          {totalValue}
        </span>
      </div>

      {/* 扇区 tooltip */}
      {hoverIdx !== null && geoms[hoverIdx] && (
        <div
          className="absolute pointer-events-none z-10 bg-bg-card border border-divider rounded-lg shadow-lg px-3 py-2 min-w-[120px] -translate-x-1/2 -translate-y-1/2"
          style={{
            left: `${geoms[hoverIdx].tipX}%`,
            top: `${geoms[hoverIdx].tipY}%`,
          }}
        >
          <div className="flex items-center gap-2 mb-1">
            <span
              className="inline-block w-2.5 h-2.5"
              style={{
                background: 'transparent',
                border: `1.5px solid ${segments[hoverIdx].color}`,
              }}
            />
            <span className="text-xs font-bold text-text-primary">
              {segments[hoverIdx].label}
            </span>
          </div>
          <div className="text-xs text-text-primary">
            ${segments[hoverIdx].value.toLocaleString('en-US', { maximumFractionDigits: 0 })}
          </div>
          <div className="text-xs text-on-surface-variant">
            {((segments[hoverIdx].value / total) * 100).toFixed(1)}%
          </div>
        </div>
      )}
    </div>
  )
}