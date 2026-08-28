import { describe, it, expect } from 'vitest'
import { getCategoryPresentation, getCategoryPresentationById } from './category-presentation'
import type { Category as ApiCategory } from '../api/categories'

describe('getCategoryPresentation', () => {
  it('looks up known expense category by id', () => {
    const c: ApiCategory = {
      id: 'expense-餐饮',
      type: 'expense',
      name: '餐饮',
      icon: '🍔',
      color: '#4299E1',
      sortOrder: 0,
    }
    const out = getCategoryPresentation(c)
    expect(out.icon).toBe('restaurant')
    expect(out.colorToken).toBe('cat-blue')
    expect(out.colorHex).toBe('#4299E1')
  })

  it('looks up known income category by id', () => {
    const c: ApiCategory = {
      id: 'income-工资',
      type: 'income',
      name: '工资',
      icon: '💰',
      color: '#10b981',
      sortOrder: 0,
    }
    const out = getCategoryPresentation(c)
    expect(out.icon).toBe('payments')
    expect(out.colorToken).toBe('secondary')
    expect(out.colorHex).toBe('#10b981')
  })

  it('falls back to outline/more_horiz for unknown id', () => {
    const c: ApiCategory = {
      id: 'expense-mystery',
      type: 'expense',
      name: '神秘',
      icon: '❓',
      color: '#000000',
      sortOrder: 99,
    }
    const out = getCategoryPresentation(c)
    expect(out.icon).toBe('more_horiz')
    expect(out.colorToken).toBe('outline')
  })

  it('covers all 9 expense + 5 income default categories', () => {
    const expenseIds = ['餐饮', '交通', '购物', '娱乐', '居住', '医疗', '教育', '通讯', '其他']
    const incomeIds = ['工资', '兼职', '理财', '红包', '其他']
    for (const n of expenseIds) {
      const out = getCategoryPresentationById(`expense-${n}`)
      expect(out.colorToken, `expense-${n}`).toBeTruthy()
    }
    for (const n of incomeIds) {
      const out = getCategoryPresentationById(`income-${n}`)
      expect(out.colorToken, `income-${n}`).toBeTruthy()
    }
  })
})

describe('getCategoryPresentationById', () => {
  it('returns same shape as getCategoryPresentation', () => {
    const a = getCategoryPresentationById('expense-购物')
    expect(a.icon).toBe('shopping_bag')
    expect(a.colorToken).toBe('cat-pink')
  })

  it('falls back consistently for unknown id', () => {
    expect(getCategoryPresentationById('xxx').icon).toBe('more_horiz')
  })
})