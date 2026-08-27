/**
 * 后端 account → 前端展示用 account 的派生字段。
 *
 * 后端 account 只有基础字段（name/type/icon/balance/currency 等）；
 * 前端 Account 卡片需要的 subtitle / themeKey / creditLimit 按 type + name 启发式派生。
 */
import type { Account as ApiAccount } from '../api/accounts'

export type ThemeKey = 'wechat' | 'alipay' | 'bank' | 'credit' | 'cash'

export interface AccountPresentation {
  /** 卡片副标题：英文类型 / 卡号占位 */
  subtitle: string
  themeKey: ThemeKey
  /** 仅信用卡：显示额度（mock 占位，真实场景需用户输入） */
  creditLimit?: string
}

const TYPE_TO_THEME: Record<ApiAccount['type'], ThemeKey> = {
  wallet: 'wechat',
  cash: 'cash',
  debit: 'bank',
  credit: 'credit',
  investment: 'bank',
  other: 'bank',
}

const TYPE_TO_SUBTITLE: Record<ApiAccount['type'], string> = {
  wallet: 'Digital Wallet',
  cash: 'Physical Currency',
  debit: 'Bank Account',
  credit: 'Credit Card',
  investment: 'Investment',
  other: 'Other Account',
}

function detectThemeByName(name: string, fallback: ThemeKey): ThemeKey {
  const n = name.toLowerCase()
  if (n.includes('微信') || n.includes('wechat')) return 'wechat'
  if (n.includes('支付宝') || n.includes('alipay')) return 'alipay'
  if (n.includes('现金') || n.includes('cash')) return 'cash'
  if (n.includes('信用') || n.includes('credit')) return 'credit'
  if (n.includes('银行') || n.includes('bank') || n.includes('工商') || n.includes('招商') || n.includes('建行') || n.includes('农行')) return 'bank'
  return fallback
}

export function getAccountPresentation(a: ApiAccount): AccountPresentation {
  const baseTheme = TYPE_TO_THEME[a.type] ?? 'bank'
  const themeKey = detectThemeByName(a.name, baseTheme)
  const subtitle = TYPE_TO_SUBTITLE[a.type] ?? 'Account'
  const result: AccountPresentation = { subtitle, themeKey }
  if (a.type === 'credit') {
    result.creditLimit = '—'
  }
  return result
}
