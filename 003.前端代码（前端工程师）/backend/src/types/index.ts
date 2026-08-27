export interface User {
  id: number
  uuid: string
  username: string
  displayName: string | null
  avatar: string | null
  gender: 'male' | 'female' | 'other' | null
  age: number | null
  createdAt: string
}

export interface JwtPayload {
  sub: number
  uuid: string
  username: string
}

// -----------------------------------------------------------------------------
// 业务模型（API 响应类型）
// -----------------------------------------------------------------------------

export type CategoryType = 'expense' | 'income'

export interface Category {
  id: string             // uuid
  type: CategoryType
  name: string
  icon: string           // emoji
  color: string          // '#RRGGBB'
}

export type AccountType = 'cash' | 'debit' | 'credit' | 'wallet' | 'investment' | 'other'

export interface Account {
  id: string              // uuid
  name: string
  type: AccountType
  icon: string
  initialBalance: number
  balance: number         // 实时计算
  currency: string
  isDefault: boolean
  sortOrder: number
  note: string | null
  createdAt: string
}

export type RecordType = 'expense' | 'income' | 'transfer'
export type RecordSource = 'manual' | 'import' | 'ocr' | 'auto' | 'sync'

export interface Record {
  id: string              // uuid
  type: RecordType
  categoryId: string | null
  accountId: string
  toAccountId: string | null
  amount: number
  currency: string
  note: string | null
  recordDate: string      // 'YYYY-MM-DD'
  source: RecordSource
  createdAt: string
  updatedAt: string
}