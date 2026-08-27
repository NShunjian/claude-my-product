import { useMemo, useRef, useState } from 'react'

interface LineChartProps {
  data: Array<{ day: number; income: number; expense: number }>
  /** 颜色：收入（蓝）/ 支出（红） */
  incomeColor?: string
  expenseColor?: string
  /** 平滑窗口大小（天）。0=不平滑。默认 5 */
  smoothWindow?: number
}

interface HoverInfo {
  idx: number
  clientX: number
}

/**
 * 每日收支趋势折线图（纯 SVG，平滑曲线 + 触摸/鼠标交互）
 * - X 轴：1 / 5 / 10 / 15 / 20 / 25 / 30 天
 * - Y 轴：硬编码 0–4000（与原型一致）
 * - 悬停 / 触摸时：显示十字线 + 数据点圆环 + 浮动 tooltip
 */
export function LineChart({
  data,
  incomeColor = '#005394',
  expenseColor = '#ba1a1a',
  smoothWindow = 5,
}: LineChartProps) {
  const W = 800
  const H = 320
  const PADDING = { top: 20, right: 20, bottom: 40, left: 50 }
  const innerW = W - PADDING.left - PADDING.right
  const innerH = H - PADDING.top - PADDING.bottom
  const svgRef = useRef<SVGSVGElement>(null)
  const [hover, setHover] = useState<HoverInfo | null>(null)

  // 移动平均平滑（默认 5 天窗口），让稀疏数据呈现连续曲线
  const smoothed = useMemo(() => {
    if (smoothWindow <= 1) return data
    return data.map((d, i) => {
      const start = Math.max(0, i - smoothWindow + 1)
      const slice = data.slice(start, i + 1)
      const inc = slice.reduce((s, x) => s + x.income, 0) / slice.length
      const exp = slice.reduce((s, x) => s + x.expense, 0) / slice.length
      return { day: d.day, income: inc, expense: exp }
    })
  }, [data, smoothWindow])

  // Y 轴硬编码 0–4000（与原型一致）
  const yMax = 4000

  const xFor = (day: number) =>
    PADDING.left + ((day - 1) / 29) * innerW
  const yFor = (val: number) =>
    PADDING.top + innerH - (val / yMax) * innerH

  // 平滑路径（Catmull-Rom → Bezier 简化版）
  function smoothPath(values: number[]): string {
    if (values.length === 0) return ''
    const pts = values.map((v, i) => ({ x: xFor(i + 1), y: yFor(v) }))
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

  const incomeValues = smoothed.map((d) => Math.min(d.income, yMax))
  const expenseValues = smoothed.map((d) => Math.min(d.expense, yMax))
  const incomePath = smoothPath(incomeValues)
  const expensePath = smoothPath(expenseValues)

  // 填充区域（收入曲线下方）
  const incomeArea =
    incomePath + ` L ${xFor(30)},${yFor(0)} L ${xFor(1)},${yFor(0)} Z`

  const yTicks = [0, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000]
  const xTicks = [1, 5, 10, 15, 20, 25, 30]

  /** 把鼠标 / 触摸 X 坐标转换为最近的数据点索引 */
  function pickIdx(clientX: number): number | null {
    const svg = svgRef.current
    if (!svg) return null
    const rect = svg.getBoundingClientRect()
    if (rect.width === 0) return null
    // 将 clientX 映射到 viewBox 的 X
    const vbX = ((clientX - rect.left) / rect.width) * W
    if (vbX < PADDING.left - 10 || vbX > W - PADDING.right + 10) return null
    const ratio = (vbX - PADDING.left) / innerW
    const day = Math.round(ratio * 29) + 1
    return Math.max(0, Math.min(29, day - 1))
  }

  function onMouseMove(e: React.MouseEvent<SVGSVGElement>) {
    const idx = pickIdx(e.clientX)
    setHover(idx === null ? null : { idx, clientX: e.clientX })
  }
  function onMouseLeave() {
    setHover(null)
  }
  function onTouchMove(e: React.TouchEvent<SVGSVGElement>) {
    if (e.touches.length > 0) {
      const idx = pickIdx(e.touches[0].clientX)
      setHover(idx === null ? null : { idx, clientX: e.touches[0].clientX })
    }
  }
  function onTouchEnd() {
    // 保持显示一段时间，让用户看清
    window.setTimeout(() => setHover(null), 1500)
  }

  const hoverData = hover ? smoothed[hover.idx] : null
  const hoverVbX = hover ? xFor(hover.idx + 1) : 0

  return (
    <div className="relative">
      <svg
        ref={svgRef}
        viewBox={`0 0 ${W} ${H}`}
        className="w-full h-auto select-none"
        preserveAspectRatio="xMidYMid meet"
        onMouseMove={onMouseMove}
        onMouseLeave={onMouseLeave}
        onTouchMove={onTouchMove}
        onTouchEnd={onTouchEnd}
      >
        {/* 网格线 + Y 轴标签 */}
        {yTicks.map((v) => (
          <g key={v}>
            <line
              x1={PADDING.left}
              y1={yFor(v)}
              x2={W - PADDING.right}
              y2={yFor(v)}
              stroke="#E2E8F0"
              strokeWidth="1"
            />
            <text
              x={PADDING.left - 8}
              y={yFor(v)}
              textAnchor="end"
              dominantBaseline="middle"
              fontSize="11"
              fill="#94a3b8"
            >
              {v.toLocaleString('en-US')}
            </text>
          </g>
        ))}

        {/* X 轴标签 */}
        {xTicks.map((d) => (
          <text
            key={d}
            x={xFor(d)}
            y={H - PADDING.bottom + 18}
            textAnchor="middle"
            fontSize="11"
            fill="#94a3b8"
          >
            {d}
          </text>
        ))}

        {/* 收入填充 */}
        <path d={incomeArea} fill={incomeColor} fillOpacity="0.1" />
        {/* 收入曲线 */}
        <path
          d={incomePath}
          stroke={incomeColor}
          strokeWidth="2"
          fill="none"
          strokeLinejoin="round"
          strokeLinecap="round"
        />
        {/* 支出曲线 */}
        <path
          d={expensePath}
          stroke={expenseColor}
          strokeWidth="2"
          fill="none"
          strokeLinejoin="round"
          strokeLinecap="round"
        />

        {/* 悬停十字虚线 */}
        {hover !== null && (
          <line
            x1={hoverVbX}
            y1={PADDING.top}
            x2={hoverVbX}
            y2={H - PADDING.bottom}
            stroke="#94a3b8"
            strokeWidth="1"
            strokeDasharray="3 3"
          />
        )}

        {/* 悬停数据点圆环 */}
        {hoverData && (
          <g>
            <circle
              cx={hoverVbX}
              cy={yFor(Math.min(hoverData.income, yMax))}
              r="5"
              fill="#fff"
              stroke={incomeColor}
              strokeWidth="2"
            />
            <circle
              cx={hoverVbX}
              cy={yFor(Math.min(hoverData.expense, yMax))}
              r="5"
              fill="#fff"
              stroke={expenseColor}
              strokeWidth="2"
            />
          </g>
        )}
      </svg>

      {/* Tooltip（HTML 覆盖层，跟随鼠标/触摸位置） */}
      {hoverData && hover && (
        <div
          className="absolute pointer-events-none bg-bg-card border border-divider rounded-lg shadow-lg px-3 py-2 z-10 min-w-[120px]"
          style={{
            left:
              hover.clientX && svgRef.current
                ? `${hover.clientX - svgRef.current.getBoundingClientRect().left}px`
                : 0,
            top: `${(yFor(Math.max(hoverData.income, hoverData.expense)) / H) * 100}%`,
            transform: 'translate(-50%, -110%)',
          }}
        >
          <div className="font-bold text-text-primary text-xs mb-1">{hoverData.day}</div>
          <div className="flex items-center gap-2 text-xs">
            <span
              className="inline-block w-2.5 h-2.5"
              style={{
                background: 'transparent',
                border: `1.5px solid ${incomeColor}`,
              }}
            />
            <span className="text-text-primary">
              收入: {Math.round(hoverData.income).toLocaleString('en-US')}
            </span>
          </div>
          <div className="flex items-center gap-2 text-xs">
            <span
              className="inline-block w-2.5 h-2.5"
              style={{
                background: 'transparent',
                border: `1.5px solid ${expenseColor}`,
              }}
            />
            <span className="text-text-primary">
              支出: {Math.round(hoverData.expense).toLocaleString('en-US')}
            </span>
          </div>
        </div>
      )}
    </div>
  )
}