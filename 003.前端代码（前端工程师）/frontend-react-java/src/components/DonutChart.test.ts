import { describe, expect, it } from 'vitest'
import { MIN_ARC_RATIO, computeDisplayRatios } from './DonutChart'

describe('computeDisplayRatios', () => {
  it('empty input → empty output', () => {
    expect(computeDisplayRatios([])).toEqual([])
  })

  it('single segment → 100% of circle', () => {
    expect(computeDisplayRatios([1])).toEqual([1])
  })

  it('sum is exactly 1 after normalization', () => {
    const out = computeDisplayRatios([0.5, 0.3, 0.15, 0.04, 0.01])
    const sum = out.reduce((a, b) => a + b, 0)
    expect(Math.abs(sum - 1)).toBeLessThan(1e-9)
  })

  it('preserves order: input ranks stay in output', () => {
    const out = computeDisplayRatios([0.5, 0.3, 0.15, 0.04, 0.01])
    for (let i = 0; i < out.length - 1; i++) {
      expect(out[i]).toBeGreaterThan(out[i + 1])
    }
  })

  it('tiny segments get amplified enough to be visible (the original complaint)', () => {
    // [51%, 25.5%, 12%, 9%, 2%, 0.5%] — 0.5% 用 sqrt 后约 3.4% 圆周 ≈ 12°,
    // 肉眼能区分它和 2% (≈ 24°)
    const out = computeDisplayRatios([0.51, 0.255, 0.119, 0.091, 0.02, 0.005])
    expect(out[0]).toBeGreaterThan(0.30) // 51% 仍是最大
    expect(out[5]).toBeGreaterThan(MIN_ARC_RATIO - 1e-9) // 0.5% 至少 floor
    expect(out[5]).toBeLessThan(out[4]) // 0.5% 仍 < 2%
    expect(out[4]).toBeLessThan(out[3]) // 2% 仍 < 9%
  })

  it('all-equal input → all-equal output', () => {
    const out = computeDisplayRatios([0.25, 0.25, 0.25, 0.25])
    out.forEach((d) => expect(d).toBeCloseTo(0.25, 9))
  })

  it('zeros: all input 0 → uniform output (no NaN, no negative)', () => {
    const out = computeDisplayRatios([0, 0, 0])
    expect(out).toHaveLength(3)
    out.forEach((d) => {
      expect(d).toBeGreaterThan(0)
      expect(d).toBeLessThanOrEqual(1)
    })
    const sum = out.reduce((a, b) => a + b, 0)
    expect(Math.abs(sum - 1)).toBeLessThan(1e-9)
  })

  it('tiny floor only kicks in for very-small / zero values, not all values', () => {
    // sqrt 后 [99%, 0.5%, 0.5%] 第一个仍远大于 floor;后两个 floor 后归一
    const out = computeDisplayRatios([0.99, 0.005, 0.005])
    expect(out[0]).toBeGreaterThan(0.85) // 99% 还是主导
    expect(out[1]).toBeCloseTo(out[2], 6) // 两个 0.5% 输入相等 → 输出相等
    expect(out[1]).toBeGreaterThanOrEqual(MIN_ARC_RATIO - 1e-9)
  })

  it('many tiny segments: sqrt differentiates them, not all same size', () => {
    // 用户原话:"看起来差不多" — 之前 fixed floor 把所有 <floor 的都顶到同一大小,
    // 看起来一样。现在 sqrt 保留相对差距。
    const out = computeDisplayRatios([0.5, 0.1, 0.05, 0.01, 0.005, 0.001])
    // 5 个小占比应各自不同(无 NaN,无负值)
    const small = out.slice(1)
    const uniq = new Set(small.map((d) => d.toFixed(4)))
    expect(uniq.size).toBeGreaterThanOrEqual(4) // 至少 4 个不同尺寸
    small.forEach((d) => expect(d).toBeGreaterThan(0))
  })
})
