/**
 * 全局领域类型定义。
 * ponytail: 1:1 对齐 uniapp api/*.ts 的类型导出,所有 .ets 模块从这里 import。
 */

// ── 用户与认证 ─────────────────────────────────────────────
export interface User {
  id: string
  username: string
  displayName?: string
  avatar?: string
  gender?: Gender
  age?: number | null
}

export type Gender = 'male' | 'female' | 'other' | null

export interface AuthLoginPayload { username: string; password: string }
export interface AuthRegisterPayload { username: string; password: string; displayName?: string }
export interface AuthMeResponse { token: string; user: User }

// ── 账本 ───────────────────────────────────────────────────
export type BookType = 'personal' | 'shared' | 'business'
export type BookRole = 'owner' | 'editor' | 'viewer'

export interface Book {
  uuid: string
  name: string
  type: BookType
  description?: string | null
  isDefault?: boolean
  role?: BookRole
  createdAt?: string
}

export interface BookCreatePayload { name: string; type: BookType; description?: string }
export interface BookUpdatePayload { description?: string | null }

// ── 账户 ───────────────────────────────────────────────────
export type AccountType = 'cash' | 'debit' | 'credit' | 'wallet' | 'investment' | 'other'

export interface Account {
  id: string
  bookId: string
  name: string
  type: AccountType
  icon?: string
  balance: number
  currency: string
  isDefault?: boolean
  isArchived?: boolean
  createdAt?: string
}

export interface AccountCreatePayload {
  name: string
  type: AccountType
  icon: string
  initialBalance: number
  currency: string
  isDefault: boolean
}

// ── 分类 ───────────────────────────────────────────────────
export type CategoryType = 'expense' | 'income'

export interface Category {
  id: string
  bookId?: string
  type: CategoryType
  name: string
  icon?: string
  color: string
  isPreset?: boolean
  createdAt?: string
}

export interface CategoryCreatePayload { type: CategoryType; name: string; icon: string; color: string }
export interface CategoryUpdatePayload { name?: string; icon?: string | null; color?: string }

// ── 流水 ───────────────────────────────────────────────────
export type RecordType = 'expense' | 'income'

export interface Record {
  id: string
  bookId: string
  type: RecordType
  amount: number
  accountId: string
  categoryId: string
  recordDate: string // YYYY-MM-DD
  note?: string
  createdAt?: string
}

export interface RecordCreatePayload {
  type: RecordType
  amount: number
  accountId: string
  categoryId: string
  recordDate: string
  note?: string
}

export interface RecordUpdatePayload {
  type?: RecordType
  amount?: number
  accountId?: string
  categoryId?: string
  recordDate?: string
  note?: string
}

// ── 报表 ───────────────────────────────────────────────────
export interface DailyPoint { date: string; day?: number; income: number; expense: number }
export interface MonthlyPoint { month: number; income: number; expense: number }
export interface CategoryTotal {
  categoryId: string
  categoryName?: string
  name?: string
  icon?: string
  color?: string
  amount?: number
  total?: number
}
export interface MonthlyReport {
  month: string
  totalIncome: number
  totalExpense: number
  netSavings: number
  lastMonthDiff?: number
  dailyPoints: DailyPoint[]
  incomeBreakdown: CategoryTotal[]
  expenseBreakdown: CategoryTotal[]
}
export interface YearlyReport {
  year: number
  totalIncome: number
  totalExpense: number
  netSavings: number
  monthlyPoints: MonthlyPoint[]
  incomeBreakdown: CategoryTotal[]
  expenseBreakdown: CategoryTotal[]
}

// ── 账本成员 ───────────────────────────────────────────────
export interface BookMember {
  userId: string
  username: string
  displayName?: string
  role: BookRole
  joinedAt?: string
}

// ── 版本 ───────────────────────────────────────────────────
export interface SystemVersion { version: string }

// ── Toast ──────────────────────────────────────────────────
export interface ToastItem { id: number; text: string }

// ── HTTP ───────────────────────────────────────────────────
export class ApiError extends Error {
  code: number
  status: number
  constructor(code: number, message: string, status: number = 0) {
    super(message)
    this.code = code
    this.status = status
    this.name = 'ApiError'
  }
}
