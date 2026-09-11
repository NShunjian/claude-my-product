// @vitest-environment jsdom
import { describe, it, expect } from 'vitest'
import {
  toTransaction,
  toTransactions,
  toCategory,
  toCategories,
  toAccount,
  toAccounts,
  numToDouble,
  currencySymbol,
} from './finance-mappers'
import type { Record as ApiRecord } from '../api/records'
import type { Account as ApiAccount } from '../api/accounts'
import type { Category as ApiCategory } from '../api/categories'

describe('finance-mappers', () => {
  describe('toTransaction', () => {
    it('maps expense record to transaction with YYYY-MM-DD date', () => {
      const r: ApiRecord = {
        id: 'r1',
        type: 'expense',
        categoryId: 'expense-餐饮',
        accountId: 'a1',
        toAccountId: null,
        amount: 35.5,
        currency: 'CNY',
        note: '午餐',
        recordDate: '2026-08-27',
        source: 'manual',
        clientId: null,
        createdAt: '2026-08-27T10:00:00.000Z',
        updatedAt: '2026-08-27T10:00:00.000Z',
      }
      const t = toTransaction(r)
      expect(t).toMatchObject({
        id: 'r1',
        date: '2026-08-27',
        type: 'expense',
        categoryId: 'expense-餐饮',
        amount: 35.5,
        note: '午餐',
        accountId: 'a1',
      })
    })

    it('maps income record and preserves categoryId', () => {
      const r: ApiRecord = {
        id: 'r2',
        type: 'income',
        categoryId: 'income-工资',
        accountId: 'a2',
        toAccountId: null,
        amount: 5000,
        currency: 'CNY',
        note: null,
        recordDate: '2026-08-01',
        source: 'manual',
        clientId: null,
        createdAt: '2026-08-01T08:00:00.000Z',
        updatedAt: '2026-08-01T08:00:00.000Z',
      }
      const t = toTransaction(r)
      expect(t).not.toBeNull()
      expect(t!.type).toBe('income')
      expect(t!.categoryId).toBe('income-工资')
    })

    it('returns null for transfer records (frontend Transaction has no transfer type)', () => {
      const r: ApiRecord = {
        id: 'r3',
        type: 'transfer',
        categoryId: null,
        accountId: 'a1',
        toAccountId: 'a2',
        amount: 100,
        currency: 'CNY',
        note: '转出',
        recordDate: '2026-08-15',
        source: 'manual',
        clientId: null,
        createdAt: '2026-08-15T12:00:00.000Z',
        updatedAt: '2026-08-15T12:00:00.000Z',
      }
      expect(toTransaction(r)).toBeNull()
    })

    it('coerces null note to empty string', () => {
      const r: ApiRecord = {
        id: 'r4',
        type: 'expense',
        categoryId: 'expense-餐饮',
        accountId: 'a1',
        toAccountId: null,
        amount: 10,
        currency: 'CNY',
        note: null,
        recordDate: '2026-08-20',
        source: 'manual',
        clientId: null,
        createdAt: '2026-08-20T08:00:00.000Z',
        updatedAt: '2026-08-20T08:00:00.000Z',
      }
      expect(toTransaction(r)!.note).toBe('')
    })

    it('coerces null categoryId to empty string', () => {
      const r: ApiRecord = {
        id: 'r5',
        type: 'expense',
        categoryId: null,
        accountId: 'a1',
        toAccountId: null,
        amount: 10,
        currency: 'CNY',
        note: 'x',
        recordDate: '2026-08-20',
        source: 'manual',
        clientId: null,
        createdAt: '2026-08-20T08:00:00.000Z',
        updatedAt: '2026-08-20T08:00:00.000Z',
      }
      expect(toTransaction(r)!.categoryId).toBe('')
    })
  })

  describe('toTransactions', () => {
    it('filters out transfer records', () => {
      const rs: ApiRecord[] = [
        {
          id: 'r1', type: 'expense', categoryId: 'expense-餐饮', accountId: 'a1',
          toAccountId: null, amount: 10, currency: 'CNY', note: null, recordDate: '2026-08-20',
          source: 'manual', clientId: null,
          createdAt: '2026-08-20T08:00:00.000Z', updatedAt: '2026-08-20T08:00:00.000Z',
        },
        {
          id: 'r2', type: 'transfer', categoryId: null, accountId: 'a1', toAccountId: 'a2',
          amount: 100, currency: 'CNY', note: null, recordDate: '2026-08-20',
          source: 'manual', clientId: null,
          createdAt: '2026-08-20T08:00:00.000Z', updatedAt: '2026-08-20T08:00:00.000Z',
        },
        {
          id: 'r3', type: 'income', categoryId: 'income-工资', accountId: 'a2',
          toAccountId: null, amount: 5000, currency: 'CNY', note: null, recordDate: '2026-08-20',
          source: 'manual', clientId: null,
          createdAt: '2026-08-20T08:00:00.000Z', updatedAt: '2026-08-20T08:00:00.000Z',
        },
      ]
      const ts = toTransactions(rs)
      expect(ts).toHaveLength(2)
      expect(ts.map(t => t.id)).toEqual(['r1', 'r3'])
    })

    it('returns empty array for empty input', () => {
      expect(toTransactions([])).toEqual([])
    })
  })

  describe('toCategory', () => {
    it('maps category id to material symbol icon and color token', () => {
      const c: ApiCategory = {
        id: 'expense-餐饮',
        type: 'expense',
        name: '餐饮',
        icon: '🍔',
        color: '#4299E1',
        sortOrder: 0,
        isPreset: true,
      }
      const out = toCategory(c)
      expect(out.id).toBe('expense-餐饮')
      expect(out.name).toBe('餐饮')
      expect(out.icon).toBe('restaurant')
      expect(out.colorToken).toBe('cat-blue')
      expect(out.kind).toBe('expense')
    })
  })

  describe('toAccount', () => {
    it('maps 微信支付 wallet account to wechat theme', () => {
      const a: ApiAccount = {
        id: 'a1',
        name: '微信支付',
        type: 'wallet',
        icon: 'payments',
        initialBalance: 0,
        balance: 100,
        currency: 'CNY',
        isDefault: true,
        sortOrder: 0,
        note: null,
        createdAt: '2026-08-20T00:00:00.000Z',
      }
      const out = toAccount(a)
      expect(out.name).toBe('微信支付')
      expect(out.subtitle).toBe('Digital Wallet')
      expect(out.themeKey).toBe('wechat')
      expect(out.balance).toBe(100)
      expect(out.creditLimit).toBeUndefined()
    })

    it('maps credit account to credit theme and adds creditLimit', () => {
      const a: ApiAccount = {
        id: 'a2',
        name: '招行信用卡',
        type: 'credit',
        icon: 'credit_card',
        initialBalance: 0,
        balance: -500,
        currency: 'CNY',
        isDefault: false,
        sortOrder: 4,
        note: null,
        createdAt: '2026-08-20T00:00:00.000Z',
      }
      const out = toAccount(a)
      expect(out.themeKey).toBe('credit')
      expect(out.subtitle).toBe('Credit Card')
      expect(out.creditLimit).toBe('—')
    })
  })

  describe('toAccounts / toCategories', () => {
    it('toAccounts maps each', () => {
      const as: ApiAccount[] = [
        {
          id: 'a1', name: '微信支付', type: 'wallet', icon: 'payments',
          initialBalance: 0, balance: 0, currency: 'CNY', isDefault: true,
          sortOrder: 0, note: null, createdAt: '2026-08-20T00:00:00.000Z',
        },
      ]
      expect(toAccounts(as)).toHaveLength(1)
    })

    it('toCategories maps each', () => {
      const cs: ApiCategory[] = [
        { id: 'expense-餐饮', type: 'expense', name: '餐饮', icon: '🍔', color: '#4299E1', sortOrder: 0, isPreset: true },
      ]
      expect(toCategories(cs)).toHaveLength(1)
    })
  })
})

describe('finance-mappers — V1.2 金额核算审计', () => {
  describe('numToDouble', () => {
    it('number → 自身', () => {
      expect(numToDouble(12.34)).toBe(12.34)
    })
    it('整数 number → 自身', () => {
      expect(numToDouble(0)).toBe(0)
      expect(numToDouble(100)).toBe(100)
    })
    it('string → 解析成 number(防 BigDecimal 字符串拼接腐坏)', () => {
      expect(numToDouble('12.34')).toBe(12.34)
      expect(numToDouble('-100')).toBe(-100)
      expect(numToDouble('0')).toBe(0)
    })
    it('null/undefined → 0 兜底', () => {
      expect(numToDouble(null)).toBe(0)
      expect(numToDouble(undefined)).toBe(0)
    })
    it('非法 string → 0 兜底', () => {
      expect(numToDouble('abc')).toBe(0)
      expect(numToDouble('')).toBe(0)
    })
    it('NaN / Infinity → 0 兜底', () => {
      expect(numToDouble(Number.NaN)).toBe(0)
      expect(numToDouble(Number.POSITIVE_INFINITY)).toBe(0)
    })
    it('支持自定义 fallback', () => {
      expect(numToDouble('abc', 99)).toBe(99)
      expect(numToDouble(null, -1)).toBe(-1)
    })
  })

  describe('currencySymbol', () => {
    it('CNY → ¥', () => expect(currencySymbol('CNY')).toBe('¥'))
    it('RMB → ¥', () => expect(currencySymbol('RMB')).toBe('¥'))
    it('USD → $', () => expect(currencySymbol('USD')).toBe('$'))
    it('EUR → €', () => expect(currencySymbol('EUR')).toBe('€'))
    it('GBP → £', () => expect(currencySymbol('GBP')).toBe('£'))
    it('JPY → ¥', () => expect(currencySymbol('JPY')).toBe('¥'))
    it('HKD → HK$', () => expect(currencySymbol('HKD')).toBe('HK$'))
    it('小写兼容', () => expect(currencySymbol('cny')).toBe('¥'))
    it('null → ¥', () => expect(currencySymbol(null)).toBe('¥'))
    it('unknown → ¥ 兜底', () => expect(currencySymbol('XYZ')).toBe('¥'))
  })

  describe('toTransaction 字符串 BigDecimal 兼容', () => {
    // 关键测试:后端 Jackson WRITE_BIGDECIMAL_AS_PLAIN 把 BigDecimal 序列化成
    // JSON 字符串(例如 "35.50")。如果 mapper 没规整成 number,
    // CategoryBreakdown 的 reduce(s + t.amount) 会字符串拼接出 "035.5012.30"。
    it('amount 是字符串时仍规整成 number', () => {
      const r: ApiRecord = {
        id: 'r3', type: 'expense',
        categoryId: 'expense-餐饮', accountId: 'a1',
        toAccountId: null,
        amount: '35.50' as unknown as number,  // 模拟后端返字符串
        currency: 'CNY', note: null,
        recordDate: '2026-09-01',
        source: 'manual', clientId: null,
        createdAt: '', updatedAt: '',
      }
      const t = toTransaction(r)
      expect(t).not.toBeNull()
      expect(typeof t!.amount).toBe('number')
      expect(t!.amount).toBe(35.5)
    })

    it('toTransaction 配合 reduce 求和仍为数字相加(无字符串拼接腐坏)', () => {
      // 模拟 CategoryBreakdown.reduce 的核心调用
      const rs: ApiRecord[] = [
        mkRec('r1', '12.30' as unknown as number),
        mkRec('r2', '5.50' as unknown as number),
        mkRec('r3', '0.20' as unknown as number),
      ]
      const sum = toTransactions(rs).reduce((s, t) => s + t.amount, 0)
      // 数字相加 12.30 + 5.50 + 0.20 = 18.00;字符串拼接会得到 "012.305.500.20"
      expect(sum).toBe(18)
    })
  })
})

function mkRec(id: string, amount: number | string): ApiRecord {
  return {
    id, type: 'expense',
    categoryId: 'expense-餐饮', accountId: 'a1',
    toAccountId: null,
    amount: amount as unknown as number,
    currency: 'CNY', note: null,
    recordDate: '2026-09-01',
    source: 'manual', clientId: null,
    createdAt: '', updatedAt: '',
  }
}