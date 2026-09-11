import type { AccountType } from '@/api/accounts'
import type { CategoryType } from '@/api/categories'

/**
 * V1.2 金额核算审计:ISO 4217 货币码 → 显示符号。
 * 没收录的码回退 `¥`,与历史行为一致。
 */
export function currencySymbol(code: string | null | undefined): string {
  switch ((code ?? '').toUpperCase()) {
    case 'CNY':
    case 'RMB': return '¥'
    case 'USD': return '$'
    case 'EUR': return '€'
    case 'GBP': return '£'
    case 'JPY': return '¥'
    case 'HKD': return 'HK$'
    default: return '¥'
  }
}

/**
 * V1.2 金额核算审计:
 *   - NaN/Infinity → '--' 而不是 '¥NaN' 炸屏。
 *   - currency 优先于 withSymbol;传 currency 时直接用货币码对应符号。
 */
export function formatAmount(
  n: number | null | undefined,
  withSymbol = false,
  currency?: string | null,
): string {
  if (n == null || !Number.isFinite(n)) return '--'
  const num = n as number
  const body = num.toLocaleString('zh-CN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  const sym = currency != null ? currencySymbol(currency) : (withSymbol ? '¥' : '')
  return sym + body
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
