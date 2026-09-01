import type { AccountType } from '@/api/accounts'
import type { CategoryType } from '@/api/categories'

export function formatAmount(n: number, withSymbol = false): string {
  return (withSymbol ? '¥' : '') + n.toFixed(2)
}

/** ISO 字符串(后端返回的 createdAt / updatedAt)格式化为本地时区 `YYYY-MM-DD HH:mm`。 */
export function formatDateTime(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
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
