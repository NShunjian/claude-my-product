import { describe, it, expect } from 'vitest'
import { getAccountPresentation } from './account-presentation'
import type { Account as ApiAccount } from '../api/accounts'

function makeAccount(overrides: Partial<ApiAccount> = {}): ApiAccount {
  return {
    id: 'a1',
    name: '默认账户',
    type: 'wallet',
    icon: 'payments',
    initialBalance: 0,
    balance: 0,
    currency: 'CNY',
    isDefault: false,
    sortOrder: 0,
    note: null,
    createdAt: '2026-08-20T00:00:00.000Z',
    ...overrides,
  }
}

describe('getAccountPresentation', () => {
  it('maps wallet type to wechat theme by default', () => {
    const out = getAccountPresentation(makeAccount({ name: 'Unknown Wallet', type: 'wallet' }))
    expect(out.themeKey).toBe('wechat')
    expect(out.subtitle).toBe('Digital Wallet')
  })

  it('overrides theme to wechat when name contains 微信', () => {
    const out = getAccountPresentation(makeAccount({ name: '微信零钱', type: 'wallet' }))
    expect(out.themeKey).toBe('wechat')
  })

  it('overrides theme to alipay when name contains 支付宝', () => {
    const out = getAccountPresentation(makeAccount({ name: '支付宝余额', type: 'wallet' }))
    expect(out.themeKey).toBe('alipay')
  })

  it('overrides theme to cash when name contains 现金', () => {
    const out = getAccountPresentation(makeAccount({ name: '钱包现金', type: 'wallet' }))
    expect(out.themeKey).toBe('cash')
  })

  it('overrides theme to credit when name contains 信用', () => {
    const out = getAccountPresentation(makeAccount({ name: '招行信用卡', type: 'credit' }))
    expect(out.themeKey).toBe('credit')
  })

  it('overrides theme to bank when name contains 工商/招商/建行/农行/银行', () => {
    expect(getAccountPresentation(makeAccount({ name: '工商银行', type: 'debit' })).themeKey).toBe('bank')
    expect(getAccountPresentation(makeAccount({ name: '招商银行', type: 'debit' })).themeKey).toBe('bank')
    expect(getAccountPresentation(makeAccount({ name: '建行储蓄卡', type: 'debit' })).themeKey).toBe('bank')
    expect(getAccountPresentation(makeAccount({ name: '农行', type: 'debit' })).themeKey).toBe('bank')
    expect(getAccountPresentation(makeAccount({ name: '中国银行', type: 'debit' })).themeKey).toBe('bank')
  })

  it('name detection is case-insensitive (English keywords)', () => {
    expect(getAccountPresentation(makeAccount({ name: 'My Wechat Pay', type: 'wallet' })).themeKey).toBe('wechat')
    expect(getAccountPresentation(makeAccount({ name: 'Alipay HK', type: 'wallet' })).themeKey).toBe('alipay')
  })

  it('credit type is sticky — names with 招商/银行 must not downgrade to bank theme', () => {
    // backend 把招商银行登记成 credit,前端不能因为名字里有 "招商/银行" 而把它当普通借记卡,
    // 否则 balance 会失去 credit 主题的负号渲染,和 backend 真值不一致。
    expect(getAccountPresentation(makeAccount({ name: '招商银行', type: 'credit' })).themeKey).toBe('credit')
    expect(getAccountPresentation(makeAccount({ name: '工商银行信用卡', type: 'credit' })).themeKey).toBe('credit')
    expect(getAccountPresentation(makeAccount({ name: '招商银行', type: 'credit' })).subtitle).toBe('Credit Card')
  })

  it('credit type adds creditLimit placeholder', () => {
    const out = getAccountPresentation(makeAccount({ type: 'credit' }))
    expect(out.creditLimit).toBe('—')
  })

  it('non-credit type does not add creditLimit', () => {
    const out = getAccountPresentation(makeAccount({ type: 'wallet' }))
    expect(out.creditLimit).toBeUndefined()
  })

  it('subtitle matches type mapping', () => {
    expect(getAccountPresentation(makeAccount({ type: 'cash' })).subtitle).toBe('Physical Currency')
    expect(getAccountPresentation(makeAccount({ type: 'debit' })).subtitle).toBe('Bank Account')
    expect(getAccountPresentation(makeAccount({ type: 'investment' })).subtitle).toBe('Investment')
    expect(getAccountPresentation(makeAccount({ type: 'other' })).subtitle).toBe('Other Account')
  })
})