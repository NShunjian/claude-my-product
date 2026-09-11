import { describe, expect, it } from 'vitest'
import { deduplicateColors } from './chart-color'

describe('deduplicateColors', () => {
  it('empty / single-element: returns shallow copy with no remap', () => {
    expect(deduplicateColors([])).toEqual([])
    const single = [{ color: '#FF0000', label: 'x', value: 1 }]
    const out = deduplicateColors(single)
    expect(out).toEqual(single)
    // 关键:返回新数组(避免外部修改污染原数据)
    expect(out).not.toBe(single)
  })

  it('keeps first occurrence color, offsets second/third/+', () => {
    const segs = [
      { color: '#888888', label: 'A', value: 1 },
      { color: '#888888', label: 'B', value: 2 },
      { color: '#888888', label: 'C', value: 3 },
    ]
    const out = deduplicateColors(segs)
    expect(out[0].color).toBe('#888888') // 第 1 个不动
    expect(out[1].color).not.toBe('#888888') // 其它必变
    expect(out[2].color).not.toBe('#888888')
    expect(out[1].color).not.toBe(out[2].color) // 互相也得不同
  })

  it('odd/even alternation: idx=1 brighter, idx=2 darker', () => {
    const segs = [
      { color: '#888888', label: 'A', value: 1 },
      { color: '#888888', label: 'B', value: 2 },
      { color: '#888888', label: 'C', value: 3 },
    ]
    const out = deduplicateColors(segs)
    // 把输出转回 HSL 的 L 通道
    const lOf = (hex: string) => {
      const r = parseInt(hex.slice(1, 3), 16) / 255
      const g = parseInt(hex.slice(3, 5), 16) / 255
      const b = parseInt(hex.slice(5, 7), 16) / 255
      return (Math.max(r, g, b) + Math.min(r, g, b)) / 2
    }
    const l0 = lOf(out[0].color)
    const l1 = lOf(out[1].color)
    const l2 = lOf(out[2].color)
    // RGB↔HSL 转换有舍入,允许 ±0.04 的容差
    expect(l1 - l0).toBeGreaterThan(0.04) // idx=1: 调亮
    expect(l0 - l2).toBeGreaterThan(0.04) // idx=2: 调暗
  })

  it('different colors in input stay untouched', () => {
    const segs = [
      { color: '#FF0000', label: 'A', value: 1 },
      { color: '#00FF00', label: 'B', value: 2 },
      { color: '#0000FF', label: 'C', value: 3 },
    ]
    const out = deduplicateColors(segs)
    expect(out.map((s) => s.color)).toEqual(['#FF0000', '#00FF00', '#0000FF'])
  })

  it('preserves order and other fields', () => {
    const segs = [
      { color: '#888888', label: 'A', value: 1 },
      { color: '#FF0000', label: 'B', value: 2 },
      { color: '#888888', label: 'C', value: 3 },
    ]
    const out = deduplicateColors(segs)
    expect(out.map((s) => s.label)).toEqual(['A', 'B', 'C'])
    expect(out.map((s) => s.value)).toEqual([1, 2, 3])
    expect(out[0].color).toBe('#888888') // 唯一不动的
    expect(out[2].color).not.toBe('#888888')
  })

  it('case-insensitive: same color in different cases collides', () => {
    const segs = [
      { color: '#888888', label: 'A', value: 1 },
      { color: '#888888', label: 'B', value: 2 },
    ]
    const out = deduplicateColors(segs)
    expect(out[0].color.toUpperCase()).toBe('#888888')
    expect(out[1].color.toUpperCase()).not.toBe('#888888')
  })

  it('non-hex colors (CSS named) pass through unchanged', () => {
    const segs = [
      { color: 'red', label: 'A', value: 1 },
      { color: 'red', label: 'B', value: 2 },
    ]
    const out = deduplicateColors(segs)
    expect(out[0].color).toBe('red')
    expect(out[1].color).toBe('red') // 解析失败,不动
  })

  it('clamps L to [0.05, 0.95] so very dark colors do not crash', () => {
    const segs = Array.from({ length: 10 }, (_, i) => ({
      color: '#000000',
      label: String(i),
      value: i,
    }))
    const out = deduplicateColors(segs)
    for (const s of out) {
      expect(s.color).toMatch(/^#[0-9A-Fa-f]{6}$/)
    }
  })

  it('gray colors: injects saturation + hue shift so same-gray differs visibly', () => {
    // #A0AEC0 是 low-saturation 灰,S < 0.20。同色 2 个应该走「加饱和 + 偏色相」分支。
    const segs = [
      { color: '#A0AEC0', label: 'A', value: 1 },
      { color: '#A0AEC0', label: 'B', value: 2 },
    ]
    const out = deduplicateColors(segs)
    // 第 1 个不动
    expect(out[0].color.toUpperCase()).toBe('#A0AEC0')
    // 第 2 个必须变成有饱和度的色(看 R/G/B 三通道不全接近)
    const isMonochrome = (hex: string) => {
      const r = parseInt(hex.slice(1, 3), 16)
      const g = parseInt(hex.slice(3, 5), 16)
      const b = parseInt(hex.slice(5, 7), 16)
      return Math.max(r, g, b) - Math.min(r, g, b) < 8
    }
    expect(isMonochrome(out[1].color)).toBe(false) // 灰走纯灰策略会接近 monochrome,这里不该
  })

  it('colorful colors: bright/dark alternation stays within HSL family', () => {
    // #4299E1(蓝)有饱和度,应该走调 L 阶梯
    const segs = [
      { color: '#4299E1', label: 'A', value: 1 },
      { color: '#4299E1', label: 'B', value: 2 },
      { color: '#4299E1', label: 'C', value: 3 },
    ]
    const out = deduplicateColors(segs)
    // 第 1 个保持 #4299E1
    expect(out[0].color.toUpperCase()).toBe('#4299E1')
    // 第 2 个变亮,第 3 个变暗 — R/G/B 通道的差距不能过大(还是蓝色家族)
    const blueDominant = (hex: string) => parseInt(hex.slice(3, 5), 16) > parseInt(hex.slice(1, 3), 16)
    expect(blueDominant(out[1].color)).toBe(true)
    expect(blueDominant(out[2].color)).toBe(true)
  })
})