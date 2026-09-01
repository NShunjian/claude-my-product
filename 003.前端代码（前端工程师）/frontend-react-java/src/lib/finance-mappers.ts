/**
 * 把后端 API 返回的数据转成前端 UI 使用的展示层类型。
 *
 * 关键差异：
 * - backend Record.recordDate (YYYY-MM-DD)  →  Transaction.date
 * - backend Record.toAccountId (transfer)   →  Transaction 暂不展示（只展示 expense/income）
 * - backend Category.icon (emoji)           →  Category.icon (Material Symbol) via lookup
 * - backend Category.color (#RRGGBB)        →  Category.colorToken (语义 token) via lookup
 * - backend Account 无 subtitle/themeKey    →  按 type + name 推导
 */
import type { Record as ApiRecord } from '../api/records'
import type { Account as ApiAccount } from '../api/accounts'
import type { Category as ApiCategory } from '../api/categories'
import type { Transaction, Account, Category } from './finance-types'
import { getCategoryPresentation } from './category-presentation'
import { getAccountPresentation } from './account-presentation'

/**
 * 后端 record 转前端 transaction。
 * transfer 类型在前端 Transaction 模型中没有 'transfer'，所以跳过（首页/流水只关心 expense/income）。
 */
export function toTransaction(r: ApiRecord): Transaction | null {
  if (r.type === 'transfer') return null
  return {
    id: r.id,
    date: r.recordDate,
    type: r.type,
    categoryId: r.categoryId ?? '',
    amount: r.amount,
    note: r.note ?? '',
    accountId: r.accountId,
    createdAt: r.createdAt,
  }
}

export function toCategory(c: ApiCategory): Category {
  const pres = getCategoryPresentation(c)
  return {
    id: c.id,
    name: c.name,
    icon: pres.icon,
    colorToken: pres.colorToken,
    kind: c.type,
  }
}

export function toAccount(a: ApiAccount): Account {
  const pres = getAccountPresentation(a)
  return {
    id: a.id,
    name: a.name,
    subtitle: pres.subtitle,
    themeKey: pres.themeKey,
    balance: a.balance,
    ...(pres.creditLimit ? { creditLimit: pres.creditLimit } : {}),
  }
}

export function toTransactions(rs: ApiRecord[]): Transaction[] {
  return rs.map(toTransaction).filter((x): x is Transaction => x !== null)
}

export function toAccounts(as: ApiAccount[]): Account[] {
  return as.map(toAccount)
}

export function toCategories(cs: ApiCategory[]): Category[] {
  return cs.map(toCategory)
}
