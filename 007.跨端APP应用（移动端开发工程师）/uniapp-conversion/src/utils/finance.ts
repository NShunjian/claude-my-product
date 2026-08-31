import type { AccountType } from '@/api/accounts'
import type { CategoryType } from '@/api/categories'

export function formatAmount(n: number, withSymbol = true): string {
  const s = (withSymbol ? '¥' : '') + n.toFixed(2)
  return s
}

export function typeOfAccount(t: AccountType): string {
  return ({ cash: '现金', debit: '借记卡', credit: '信用卡', wallet: '钱包', investment: '投资', other: '其他' } as const)[t] ?? '其他'
}

export function typeOfCategory(t: CategoryType): 'expense' | 'income' | 'transfer' {
  return t
}

export function balanceSign(n: number): -1 | 0 | 1 {
  return n < 0 ? -1 : n > 0 ? 1 : 0
}
