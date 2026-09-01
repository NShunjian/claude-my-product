/**
 * 前端展示层类型 —— UI 组件使用的"视图模型"。
 *
 * 与后端契约不完全一致（详见 lib/finance-mappers.ts 的 toTransaction/toCategory/toAccount）。
 *
 * 类型来源：原 data/*.ts 的 mock 模块；Batch 4 把类型内联到此处，删除了 data/* 的 mock 数据文件。
 */

export type CategoryKind = 'expense' | 'income'

export type ColorToken =
  | 'cat-pink'
  | 'cat-blue'
  | 'cat-purple'
  | 'cat-teal'
  | 'cat-brown'
  | 'cat-orange'
  | 'cat-cyan'
  | 'cat-indigo'
  | 'secondary'
  | 'outline'

export interface Category {
  id: string
  name: string
  icon: string // Material Symbols name
  colorToken: ColorToken
  kind: CategoryKind
}

export type ThemeKey = 'wechat' | 'alipay' | 'bank' | 'credit' | 'cash'

export interface Account {
  id: string
  name: string
  subtitle: string
  themeKey: ThemeKey
  balance: number
  isDefault?: boolean
  creditLimit?: string
  icon?: string
  type?: 'cash' | 'debit' | 'credit' | 'wallet' | 'investment' | 'other'
}

export type TransactionType = 'expense' | 'income' | 'transfer'

export interface Transaction {
  id: string
  /** YYYY-MM-DD */
  date: string
  type: TransactionType
  categoryId: string
  amount: number
  note: string
  accountId: string
  /** ISO 字符串;UI 显示 HH:MM 表示此笔账的记账时间 */
  createdAt?: string
}