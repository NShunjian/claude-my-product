import { request } from '../lib/api'

export type AccountType = 'cash' | 'debit' | 'credit' | 'wallet' | 'investment' | 'other'

export interface Account {
  id: string
  name: string
  type: AccountType
  icon: string
  initialBalance: number
  /** 实时余额（来自 v_account_balance 视图） */
  balance: number
  currency: string
  isDefault: boolean
  sortOrder: number
  note: string | null
  createdAt: string
}

export interface ListAccountsResponse {
  items: Account[]
}

export interface CreateAccountInput {
  name: string
  type: AccountType
  icon: string
  initialBalance?: number
  currency?: string
  isDefault?: boolean
  sortOrder?: number
  note?: string | null
}

export interface UpdateAccountInput {
  name?: string
  type?: AccountType
  icon?: string
  initialBalance?: number
  currency?: string
  isDefault?: boolean
  sortOrder?: number
  note?: string | null
}

/** 列表中若含已软删账户的占位，目前后端默认过滤；保留 fallback 字段供前端判断。 */
export interface AccountEnvelope {
  account: Account
}

export async function listAccounts(): Promise<Account[]> {
  const res = await request<ListAccountsResponse>('/api/accounts')
  return res.items
}

export async function getAccount(id: string): Promise<Account> {
  const res = await request<AccountEnvelope>(`/api/accounts/${id}`)
  return res.account
}

export async function createAccount(input: CreateAccountInput): Promise<Account> {
  const res = await request<AccountEnvelope>('/api/accounts', {
    method: 'POST',
    body: JSON.stringify(input),
  })
  return res.account
}

export async function updateAccount(id: string, input: UpdateAccountInput): Promise<Account> {
  const res = await request<AccountEnvelope>(`/api/accounts/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(input),
  })
  return res.account
}

export async function deleteAccount(id: string): Promise<void> {
  await request<{ ok: true }>(`/api/accounts/${id}`, { method: 'DELETE' })
}
