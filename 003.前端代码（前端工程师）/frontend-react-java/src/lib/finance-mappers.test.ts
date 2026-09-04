// @vitest-environment jsdom
import { describe, it, expect } from 'vitest'
import {
  toTransaction,
  toTransactions,
  toCategory,
  toCategories,
  toAccount,
  toAccounts,
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