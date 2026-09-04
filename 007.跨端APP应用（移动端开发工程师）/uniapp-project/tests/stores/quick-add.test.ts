/**
 * 007 uniapp-project — stores/quick-add.ts Pinia 状态机测试(真实断言)
 *
 * 覆盖目标(007-uniapp-project.md §6.1):
 *   - open('expense') → show=true, kind='expense'
 *   - open('income') → show=true, kind='income'
 *   - close() → show=false
 *   - notifySaved() → savedAt 自增
 *   - 多个 page 共享同一 store(uniapp 跨页组件关键)
 *
 * 工具:vitest + pinia testing helper(setActivePinia + createPinia)
 */
import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import { createPinia, setActivePinia } from 'pinia'
import { useQuickAddStore } from '@/stores/quick-add'

beforeEach(() => {
  setActivePinia(createPinia())
})

afterEach(() => {
  setActivePinia(null)
})

describe('stores/quick-add — open / close 状态机', () => {
  it('初始状态:show=false, kind="expense", savedAt=0', () => {
    const s = useQuickAddStore()
    expect(s.show).toBe(false)
    expect(s.kind).toBe('expense')
    expect(s.savedAt).toBe(0)
  })

  it('open() 不传参 → 默认 expense, show=true', () => {
    const s = useQuickAddStore()
    s.open()
    expect(s.show).toBe(true)
    expect(s.kind).toBe('expense')
  })

  it("open('expense') → show=true, kind='expense'", () => {
    const s = useQuickAddStore()
    s.open('expense')
    expect(s.show).toBe(true)
    expect(s.kind).toBe('expense')
  })

  it("open('income') → show=true, kind='income'", () => {
    const s = useQuickAddStore()
    s.open('income')
    expect(s.show).toBe(true)
    expect(s.kind).toBe('income')
  })

  it('close() → show=false(kind 不变,留作下次 open 的初始值)', () => {
    const s = useQuickAddStore()
    s.open('income')
    s.close()
    expect(s.show).toBe(false)
    expect(s.kind).toBe('income') // kind 记忆,不变
  })

  it('open / close / open 多次切换', () => {
    const s = useQuickAddStore()
    s.open('expense')
    expect(s.show).toBe(true)
    s.close()
    expect(s.show).toBe(false)
    s.open('income')
    expect(s.show).toBe(true)
    expect(s.kind).toBe('income')
  })
})

describe('stores/quick-add — notifySaved 单调递增', () => {
  it('notifySaved() → savedAt 加 1', () => {
    const s = useQuickAddStore()
    expect(s.savedAt).toBe(0)
    s.notifySaved()
    expect(s.savedAt).toBe(1)
    s.notifySaved()
    expect(s.savedAt).toBe(2)
    s.notifySaved()
    expect(s.savedAt).toBe(3)
  })

  it('savedAt 是单调递增(不会回到 0)', () => {
    const s = useQuickAddStore()
    s.notifySaved() // 1
    s.notifySaved() // 2
    s.close() // 不影响 savedAt
    s.open() // 不影响 savedAt
    expect(s.savedAt).toBe(2)
  })
})

describe('stores/quick-add — 跨 page 共享同一 store', () => {
  it('多个 useQuickAddStore() 调用返回同一实例', () => {
    const a = useQuickAddStore()
    const b = useQuickAddStore()
    expect(a).toBe(b) // 同一个对象引用
  })

  it('page A open → page B 看到 show=true(共享 state)', () => {
    const a = useQuickAddStore()
    a.open('income')
    const b = useQuickAddStore()
    expect(b.show).toBe(true)
    expect(b.kind).toBe('income')
  })

  it('page B notifySaved → page A 看到 savedAt 自增', () => {
    const a = useQuickAddStore()
    const b = useQuickAddStore()
    b.notifySaved()
    expect(a.savedAt).toBe(1)
    a.notifySaved()
    expect(b.savedAt).toBe(2)
  })
})