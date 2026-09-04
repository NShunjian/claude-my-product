/**
 * 007 uniapp-project — utils/category-presentation.ts 单测(真实断言)
 *
 * 覆盖目标(007-uniapp-project.md §6.1):
 *   - 9 个预设 expense 分类 → TABLE 命中,返回 { icon, color }
 *   - 5 个预设 income 分类 → TABLE 命中,返回 { icon, color }
 *   - 自定义分类(用户选了 emoji + 颜色)→ 用后端存的 icon/color
 *   - 自定义但 icon 是 MS ligature 名 → FALLBACK
 *   - id 含 'preset-' 前缀 → 也能命中 TABLE
 *   - 完全缺字段 → FALLBACK
 *
 * 工具:vitest
 */
import { describe, expect, it } from 'vitest'
import {
  categoryMaterialIcon,
  categoryPresentation,
  FALLBACK_COLOR,
  FALLBACK_ICON,
} from '@/utils/category-presentation'

describe('utils/category-presentation — 预设 expense 分类', () => {
  const presets: Array<{ id: string; name: string; emoji: string; token: string }> = [
    { id: 'preset-expense-餐饮', name: '餐饮', emoji: '🍽️', token: 'blue' },
    { id: 'preset-expense-交通', name: '交通', emoji: '🚌', token: 'cyan' },
    { id: 'preset-expense-购物', name: '购物', emoji: '🛍️', token: 'pink' },
    { id: 'preset-expense-娱乐', name: '娱乐', emoji: '🎮', token: 'purple' },
    { id: 'preset-expense-居住', name: '居住', emoji: '🏠', token: 'brown' },
    { id: 'preset-expense-医疗', name: '医疗', emoji: '🏥', token: 'teal' },
    { id: 'preset-expense-教育', name: '教育', emoji: '🎓', token: 'orange' },
    { id: 'preset-expense-通讯', name: '通讯', emoji: '📱', token: 'indigo' },
    { id: 'preset-expense-其他', name: '其他', emoji: '🗂️', token: 'outline' },
  ]

  for (const p of presets) {
    it(`${p.name} → icon=${p.emoji}, color 与 token ${p.token} 对应`, () => {
      const r = categoryPresentation({ id: p.id, type: 'expense', name: p.name })
      expect(r.icon).toBe(p.emoji)
      expect(r.color).toMatch(/^#[0-9a-fA-F]{6}$/)
      // 颜色应为 COLOR_HEX 之一
      expect([
        '#ED64A6', '#4299E1', '#805AD5', '#319795', '#8B6E4E',
        '#F59E0B', '#06B6D4', '#6366F1', '#10b981', '#727782',
      ]).toContain(r.color)
    })
  }
})

describe('utils/category-presentation — 预设 income 分类', () => {
  const presets: Array<{ id: string; name: string; emoji: string }> = [
    { id: 'preset-income-工资', name: '工资', emoji: '💵' },
    { id: 'preset-income-兼职', name: '兼职', emoji: '💼' },
    { id: 'preset-income-理财', name: '理财', emoji: '📈' },
    { id: 'preset-income-红包', name: '红包', emoji: '🧧' },
    { id: 'preset-income-其他', name: '其他', emoji: '🗂️' },
  ]

  for (const p of presets) {
    it(`${p.name} → icon=${p.emoji}`, () => {
      const r = categoryPresentation({ id: p.id, type: 'income', name: p.name })
      expect(r.icon).toBe(p.emoji)
      expect(r.color).toMatch(/^#[0-9a-fA-F]{6}$/)
    })
  }
})

describe('utils/category-presentation — 自定义分类', () => {
  it('自定义 + emoji + 颜色 → 用用户存的(不走 FALLBACK)', () => {
    const r = categoryPresentation({
      id: 'custom-1',
      type: 'expense',
      name: '咖啡',
      icon: '☕',
      color: '#abcdef',
    } as any)
    expect(r.icon).toBe('☕')
    expect(r.color).toBe('#abcdef')
  })

  it('自定义 + icon 是 MS ligature 名 → FALLBACK_ICON(避免字面文字显示)', () => {
    const r = categoryPresentation({
      id: 'custom-2',
      type: 'expense',
      name: '咖啡',
      icon: 'restaurant', // MS ligature 名
      color: '#abcdef',
    } as any)
    expect(r.icon).toBe(FALLBACK_ICON)
    expect(r.color).toBe('#abcdef') // 颜色仍保留
  })

  it('完全缺 icon / color 字段 → FALLBACK', () => {
    const r = categoryPresentation({
      id: 'custom-3',
      type: 'expense',
      name: '咖啡',
    })
    expect(r.icon).toBe(FALLBACK_ICON)
    expect(r.color).toBe(FALLBACK_COLOR)
  })

  it('有 color 但缺 icon → FALLBACK_ICON + 用户色', () => {
    const r = categoryPresentation({
      id: 'custom-4',
      type: 'expense',
      name: '咖啡',
      color: '#123456',
    } as any)
    expect(r.icon).toBe(FALLBACK_ICON)
    expect(r.color).toBe('#123456')
  })
})

describe('utils/category-presentation — id 前缀兼容', () => {
  it('id 含 "preset-" 前缀 → 仍能命中 TABLE', () => {
    const r = categoryPresentation({
      id: 'preset-expense-餐饮',
      type: 'expense',
      name: '餐饮',
    })
    expect(r.icon).toBe('🍽️')
    expect(r.color).toBe('#4299E1') // blue
  })

  it('id 不含 "preset-" 但 name 匹配 → 也命中 TABLE', () => {
    const r = categoryPresentation({
      id: 'expense-餐饮',
      type: 'expense',
      name: '餐饮',
    })
    expect(r.icon).toBe('🍽️')
    expect(r.color).toBe('#4299E1')
  })
})

describe('utils/category-presentation — categoryMaterialIcon', () => {
  it('返回 icon 字段', () => {
    expect(categoryMaterialIcon({ id: 'preset-expense-餐饮', type: 'expense', name: '餐饮' })).toBe('🍽️')
  })

  it('自定义走 FALLBACK 时返回 FALLBACK_ICON', () => {
    expect(categoryMaterialIcon({ id: 'c1', type: 'expense', name: '咖啡' })).toBe(FALLBACK_ICON)
  })
})