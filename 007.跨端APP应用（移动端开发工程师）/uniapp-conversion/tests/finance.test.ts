import { describe, it, expect } from 'vitest'
import { formatAmount, typeOfAccount, typeOfCategory, balanceSign } from '@/utils/finance'

describe('finance utils', () => {
  it('formatAmount: 正数带 ¥,两位小数', () => {
    expect(formatAmount(12.5)).toMatch(/12\.50/)
    expect(formatAmount(0)).toMatch(/0\.00/)
  })
  it('typeOfAccount', () => {
    expect(typeOfAccount('cash')).toBe('现金')
    expect(typeOfAccount('debit')).toBe('借记卡')
  })
  it('typeOfCategory: expense 走支出图标, income 走收入图标', () => {
    expect(typeOfCategory('expense')).toBe('expense')
    expect(typeOfCategory('income')).toBe('income')
  })
  it('balanceSign', () => {
    expect(balanceSign(100)).toBe(1)
    expect(balanceSign(-50)).toBe(-1)
    expect(balanceSign(0)).toBe(0)
  })
})
