/**
 * LineChart:对齐 uniapp components/charts/LineChart.vue 1:1。
 * ponytail: Catmull-Rom 平滑 + YMAX=4000,ArkUI Path 渲染。
 */
import type { DailyPoint } from '../../model/Types'
import { themeStore } from '../../stores/theme'
import { getTheme as resolveTheme } from '../../theme/tokens'

const YMAX_DEFAULT = 4000

interface Padding { top: number; right: number; bottom: number; left: number }
const PADDING: Padding = { top: 16, right: 12, bottom: 28, left: 36 }

interface XYPoint { x: number; y: number }

function smoothPath(points: XYPoint[]): string {
  if (points.length === 0) return ''
  if (points.length === 1) return `M ${points[0].x} ${points[0].y}`
  let d = `M ${points[0].x} ${points[0].y}`
  for (let i = 0; i < points.length - 1; i++) {
    const p0 = (i - 1 >= 0) ? points[i - 1] : points[i]
    const p1 = points[i]
    const p2 = points[i + 1]
    const p3 = (i + 2 < points.length) ? points[i + 2] : p2
    const cp1x = p1.x + (p2.x - p0.x) / 6
    const cp1y = p1.y + (p2.y - p0.y) / 6
    const cp2x = p2.x - (p3.x - p1.x) / 6
    const cp2y = p2.y - (p3.y - p1.y) / 6
    d += ` C ${cp1x} ${cp1y}, ${cp2x} ${cp2y}, ${p2.x} ${p2.y}`
  }
  return d
}

@Component
export struct LineChart {
  @Prop data: DailyPoint[] = []
  @Prop smoothWindow: number = 1
  @Prop chartWidth: number = 320
  @Prop chartHeight: number = 180

  private chartW(): number { return this.chartWidth - PADDING.left - PADDING.right }
  private chartH(): number { return this.chartHeight - PADDING.top - PADDING.bottom }

  private maxValue(): number {
    let maxIncome = 0
    let maxExpense = 0
    for (const d of this.data) {
      if (d.income > maxIncome) maxIncome = d.income
      if (d.expense > maxExpense) maxExpense = d.expense
    }
    const m = Math.max(maxIncome, maxExpense, 0)
    return Math.max(YMAX_DEFAULT, Math.ceil(m / 1000) * 1000)
  }

  private pointsFor(field: 'income' | 'expense'): XYPoint[] {
    const len = this.data.length || 1
    const step = this.chartW() / Math.max(len - 1, 1)
    const ymax = this.maxValue()
    const out: XYPoint[] = []
    for (let i = 0; i < this.data.length; i++) {
      const d = this.data[i]
      const x = PADDING.left + step * i
      const v: number = field === 'income' ? d.income : d.expense
      const ratio: number = ymax === 0 ? 0 : v / ymax
      const y: number = PADDING.top + this.chartH() * (1 - ratio)
      const p: XYPoint = { x: x, y: y }
      out.push(p)
    }
    return out
  }

  build() {
    Column() {
      Path()
        .width(this.chartWidth).height(this.chartHeight)
        .commands(smoothPath(this.pointsFor('income')))
        .stroke('#005394').strokeWidth(2).fill(Color.Transparent)
      Path()
        .width(this.chartWidth).height(this.chartHeight)
        .commands(smoothPath(this.pointsFor('expense')))
        .stroke('#BA1A1A').strokeWidth(2).fill(Color.Transparent)
    }
    .width(this.chartWidth).height(this.chartHeight)
    .backgroundColor(resolveTheme(themeStore.effective).colors.bgCard)
  }
}