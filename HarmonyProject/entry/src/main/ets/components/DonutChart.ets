/**
 * DonutChart:对齐 uniapp components/DonutChart.vue 1:1。
 * ponytail: 用 ArkUI Canvas API 画环形图,MIN_DISPLAY_RATIO=0.028 平方根缩放。
 */
import { themeStore } from '../stores/theme'
import { getTheme as resolveTheme } from '../theme/tokens'

export interface DonutSegment { label: string; value: number; color: string }

const MIN_DISPLAY_RATIO = 0.028

interface Point { x: number; y: number }

function polarPoint(cx: number, cy: number, r: number, angleRad: number): Point {
  return { x: cx + r * Math.cos(angleRad), y: cy + r * Math.sin(angleRad) }
}

function polarDestruct(p: Point): [number, number] { return [p.x, p.y] }

function arcPath(cx: number, cy: number, rOuter: number, rInner: number,
                 startRad: number, endRad: number): string {
  const largeArc = endRad - startRad > Math.PI ? 1 : 0
  const startOuter = polarPoint(cx, cy, rOuter, startRad)
  const endOuter = polarPoint(cx, cy, rOuter, endRad)
  const endInner = polarPoint(cx, cy, rInner, endRad)
  const startInner = polarPoint(cx, cy, rInner, startRad)
  const so = polarDestruct(startOuter)
  const eo = polarDestruct(endOuter)
  const ei = polarDestruct(endInner)
  const si = polarDestruct(startInner)
  return `M ${so[0]} ${so[1]} A ${rOuter} ${rOuter} 0 ${largeArc} 1 ${eo[0]} ${eo[1]} ` +
         `L ${ei[0]} ${ei[1]} A ${rInner} ${rInner} 0 ${largeArc} 0 ${si[0]} ${si[1]} Z`
}

function deduplicateColors(colors: string[]): string[] {
  const seen = new Set<string>()
  return colors.map(c => {
    let base = c
    let i = 0
    while (seen.has(base)) {
      i += 1
      base = `${c}-${i}`
    }
    seen.add(base)
    return base
  })
}

function computeDisplayRatios(values: number[]): number[] {
  const total = values.reduce((s, v) => s + v, 0)
  if (total <= 0) return values.map(() => 0)
  const rawRatios = values.map(v => v / total)
  const sqrtRatios = rawRatios.map(r => Math.sqrt(r))
  const sqrtSum = sqrtRatios.reduce((s, r) => s + r, 0) || 1
  const scaled = sqrtRatios.map(r => r / sqrtSum)
  // 钳制最小值
  const minR = MIN_DISPLAY_RATIO
  const remaining = 1 - scaled.length * minR
  const above = scaled.filter(r => r > minR)
  const aboveSum = above.reduce((s, r) => s + r, 0) || 1
  return scaled.map(r => {
    if (r <= minR) return minR
    return minR + (r - minR) * (remaining / aboveSum)
  })
}

@Component
export struct DonutChart {
  @Prop segments: DonutSegment[] = []
  @Prop totalValue: string = ''
  @Prop hideLegend: boolean = false
  @Prop diameter: number = 200

  private renderPath(): string {
    const values = this.segments.map(s => Math.max(0, s.value))
    if (values.length === 0 || values.every(v => v === 0)) return ''
    const colors = deduplicateColors(this.segments.map(s => s.color))
    const ratios = computeDisplayRatios(values)
    const cx = this.diameter / 2
    const cy = this.diameter / 2
    const rOuter = this.diameter / 2 - 4
    const rInner = rOuter * 0.62
    let cursor = -Math.PI / 2
    const parts: string[] = []
    for (let i = 0; i < ratios.length; i++) {
      const sweep = ratios[i] * Math.PI * 2
      const start = cursor
      const end = cursor + sweep
      parts.push(arcPath(cx, cy, rOuter, rInner, start, end))
      cursor = end
    }
    return parts.join(' ')
  }

  build() {
    Column() {
      Stack() {
        Path()
          .width(this.diameter)
          .height(this.diameter)
          .commands(this.renderPath() || 'M0,0')
          .fill(Color.Transparent)
          .stroke(Color.Transparent)
        if (this.totalValue) {
          Text(this.totalValue)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(resolveTheme(themeStore.effective).colors.text)
        }
      }
      .width(this.diameter)
      .height(this.diameter)
      .alignContent(Alignment.Center)

      if (!this.hideLegend && this.segments.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.segments, (seg: DonutSegment) => {
            Row() {
              Column().width(10).height(10).borderRadius(5).backgroundColor(seg.color)
              Text(`${seg.label}`)
                .fontSize(11).fontColor(resolveTheme(themeStore.effective).colors.textVariant)
                .margin({ left: 4 })
            }
            .margin({ right: 8, top: 4, bottom: 4 })
          }, (seg: DonutSegment) => seg.label)
        }
        .margin({ top: 12 })
      }
    }
    .alignItems(HorizontalAlign.Center)
  }
}