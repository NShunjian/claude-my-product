export interface User {
  id: string
  username: string
  passwordHash: string
  salt: string
  createdAt: number
}

export interface Category {
  id: string
  type: 'expense' | 'income'
  name: string
  icon: string
  color: string
  isPreset: boolean
  sortOrder: number
}

export interface Account {
  id: string
  name: string
  icon: string
  initialBalance: number
  balance: number
  isDefault: boolean
  sortOrder: number
}

export interface Record {
  id: string
  type: 'expense' | 'income'
  categoryId: string
  amount: number
  accountId: string
  note: string
  recordDate: string // YYYY-MM-DD
  createdAt: number
  updatedAt: number
}

export interface RecordWithDetails extends Record {
  category: Category
  account: Account
}

export type ViewType = 'home' | 'report' | 'account' | 'settings'
