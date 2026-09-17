/**
 * 金额与账户类型工具:与 uniapp utils/finance.ts 1:1 对齐。
 */
import type { Account } from '../model/Types'

export function currencySymbol(_currency: string = 'CNY'): string { return '¥' }

export function formatAmount(value: number, showSign: boolean = false): string {
  if (!Number.isFinite(value)) return '0.00'
  const abs = Math.abs(value)
  const fixed = abs.toFixed(2)
  const parts = fixed.split('.')
  const intPart = parts[0]
  const decPart = parts[1] ?? '00'
  const grouped = intPart.replace(/\B(?=(\d{3})+(?!\d))/g, ',')
  const formatted = `${grouped}.${decPart}`
  if (showSign) return value >= 0 ? `+${formatted}` : `-${formatted}`
  return value < 0 ? `-${formatted}` : formatted
}

export function formatDateTime(iso: string): string {
  const d = new Date(iso)
  if (Number.isNaN(d.getTime())) return iso
  const pad = (n: number): string => n.toString().padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

const typeNames = new Map<string, string>([
  ['cash', '现金'],
  ['debit', '借记卡'],
  ['credit', '信用卡'],
  ['wallet', '电子钱包'],
  ['investment', '投资'],
  ['other', '其他'],
])

export function typeOfAccount(t: string): string {
  return typeNames.get(t) ?? '其他'
}

export function balanceSign(_a: Account): 1 | -1 { return 1 }