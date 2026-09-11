/**
 * 图表撞色重映射(同色差异化)。
 *
 * 同一图表内出现 ≥2 个 hex 相同的扇区时(常见:用户自建了多个未选色
 * 自定义分类撞后端默认色、或 preset seed 本身就撞色),逐个调高亮度
 * 直到肉眼可区分。同色按出现顺序:第 1 个不动,第 2 个 +20%,第 3 个
 * -20%,第 4 个 +40%,第 5 个 -40% ……奇偶交错 +L/-L,避免全往一边偏。
 *
 * 保留 H/S,只动 L — 同一基础色视觉族,但亮度阶梯拉开。
 */

interface ColorSegment {
  color: string
}

/** '#RRGGBB' → {r,g,b} 0..255。异常输入原样返回。 */
function hexToRgb(hex: string): { r: number; g: number; b: number } | null {
  const m = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex.trim())
  if (!m) return null
  return {
    r: parseInt(m[1], 16),
    g: parseInt(m[2], 16),
    b: parseInt(m[3], 16),
  }
}

function rgbToHex(r: number, g: number, b: number): string {
  const clamp = (n: number) => Math.max(0, Math.min(255, Math.round(n)))
  const h = (n: number) => clamp(n).toString(16).padStart(2, '0')
  return `#${h(r)}${h(g)}${h(b)}`
}

/** 0..255 RGB → HSL */
function rgbToHsl(r: number, g: number, b: number): { h: number; s: number; l: number } {
  const rn = r / 255
  const gn = g / 255
  const bn = b / 255
  const max = Math.max(rn, gn, bn)
  const min = Math.min(rn, gn, bn)
  const l = (max + min) / 2
  let h = 0
  let s = 0
  if (max !== min) {
    const d = max - min
    s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
    switch (max) {
      case rn:
        h = ((gn - bn) / d + (gn < bn ? 6 : 0))
        break
      case gn:
        h = ((bn - rn) / d + 2)
        break
      default:
        h = ((rn - gn) / d + 4)
    }
    h *= 60
  }
  return { h, s, l }
}

/** HSL → 0..255 RGB */
function hslToRgb(h: number, s: number, l: number): { r: number; g: number; b: number } {
  const c = (1 - Math.abs(2 * l - 1)) * s
  const hp = h / 60
  const x = c * (1 - Math.abs((hp % 2) - 1))
  let r = 0
  let g = 0
  let b = 0
  if (hp >= 0 && hp < 1) [r, g, b] = [c, x, 0]
  else if (hp < 2) [r, g, b] = [x, c, 0]
  else if (hp < 3) [r, g, b] = [0, c, x]
  else if (hp < 4) [r, g, b] = [0, x, c]
  else if (hp < 5) [r, g, b] = [x, 0, c]
  else [r, g, b] = [c, 0, x]
  const m = l - c / 2
  return {
    r: Math.round((r + m) * 255),
    g: Math.round((g + m) * 255),
    b: Math.round((b + m) * 255),
  }
}

/**
 * 输入 segments(任意结构,但要有 color:string 字段),返回新数组:
 * 顺序不变,hex 重复的逐个差异化。
 * - 同色第 1 个保持原色,后续按出现顺序错开。
 * - 颜色 ≥ 1 处撞色才动;否则整个数组零改动。
 *
 * 两套策略:
 * - **彩色**(S ≥ 0.20):调 L ±20% 阶梯(保留原色相,只拉亮度)。
 * - **灰/低饱和**(S < 0.20):纯灰调 L 视觉差异小,所以注入饱和 + 微偏色相,
 *   让相邻两段能肉眼区分。
 */
export function deduplicateColors<T extends ColorSegment>(segments: readonly T[]): T[] {
  if (segments.length <= 1) return [...segments]
  // 先按原顺序记录每个 color 在"同色队列"里第几个出现(0-based)。
  const sameIndex = new Map<string, number>()
  return segments.map((seg) => {
    const key = seg.color.trim().toUpperCase()
    const idx = sameIndex.get(key) ?? 0
    sameIndex.set(key, idx + 1)
    if (idx === 0) return seg // 第 1 个保持原色,其它人绕开它
    const rgb = hexToRgb(seg.color)
    if (!rgb) return seg // 非 hex 格式不动(命名色等)
    const hsl = rgbToHsl(rgb.r, rgb.g, rgb.b)
    const step = 0.2
    const magnitude = Math.ceil(idx / 2) * step
    const direction = idx % 2 === 1 ? 1 : -1
    let newH = hsl.h
    let newS = hsl.s
    // 调亮/调暗都封顶到 [0.3, 0.7],避免 0.89 这种"太浅"或 0.10 这种"太暗"
    let newL = Math.max(0.3, Math.min(0.7, hsl.l + direction * magnitude))
    // 阈值 0.30(含 #A0AEC0 这种 S=0.20 的"看起来灰但擦边"色)— 走灰策略更明显。
    if (hsl.s < 0.3) {
      // 灰/低饱和:加饱和 + 偏色相,让肉眼能区分
      newS = Math.min(0.7, 0.55 + magnitude * 0.3)
      // idx=1 → 蓝(220°);idx=2 → 暖橙(30°);idx=3 → 紫(290°);idx=4 → 绿(140°)…
      const huePool = [220, 30, 290, 140, 10, 260, 180]
      newH = huePool[(idx - 1) % huePool.length]
      // 灰系 L 调节幅度更小,锁在中段 ±10%
      newL = Math.max(0.35, Math.min(0.65, 0.5 + direction * 0.08))
    }
    const out = hslToRgb(newH, newS, newL)
    return { ...seg, color: rgbToHex(out.r, out.g, out.b) }
  })
}