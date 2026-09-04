/**
 * 007 uniapp-project — utils/nav-intent.ts 单测(真实断言)
 *
 * 覆盖目标(007-uniapp-project.md §6.1):
 *   - setPendingMonth(m) → consumePendingMonth() 返回 m,然后清空
 *   - 一次性意图跨页传参(uni.switchTab 不支持 url query 的替代方案)
 *   - 消费即销毁:consume 后再 consume 应为 null
 *   - 默认状态(从未 set):consume 返回 null
 *
 * 工具:vitest
 */
import { describe, expect, it } from 'vitest'
import { consumePendingMonth, setPendingMonth } from '@/utils/nav-intent'

describe('utils/nav-intent — 一次性意图跨页传参', () => {
  it('默认状态 consume → null', () => {
    expect(consumePendingMonth()).toBeNull()
  })

  it('setPendingMonth("2026-09") → consume 返回 "2026-09"', () => {
    setPendingMonth('2026-09')
    expect(consumePendingMonth()).toBe('2026-09')
  })

  it('消费即销毁 — consume 后再 consume → null', () => {
    setPendingMonth('2026-09')
    expect(consumePendingMonth()).toBe('2026-09')
    expect(consumePendingMonth()).toBeNull()
  })

  it('多次 setPendingMonth → consume 取最后那次的值', () => {
    setPendingMonth('2026-08')
    setPendingMonth('2026-09')
    setPendingMonth('2026-10')
    expect(consumePendingMonth()).toBe('2026-10')
    expect(consumePendingMonth()).toBeNull()
  })

  it('setPendingMonth("") 空串 → consume 也返回空串(不为 null)', () => {
    // 单元测试断言 set/get 的传递;空串不算默认
    setPendingMonth('')
    expect(consumePendingMonth()).toBe('')
    expect(consumePendingMonth()).toBeNull()
  })
})