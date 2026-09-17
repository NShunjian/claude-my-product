/**
 * 账户 API:对齐 uniapp api/accounts.ts 1:1。
 */
import { request } from './http'
import type { Account, AccountCreatePayload, AccountType } from '../model/Types'

export interface ListAccountsParams {
  bookId: string
  includeArchived?: boolean
}

export function listAccounts(params: ListAccountsParams): Promise<Account[]> {
  const q = `?bookId=${encodeURIComponent(params.bookId)}${params.includeArchived ? '&includeArchived=true' : ''}`
  return request<Account[]>(`/accounts${q}`)
}

export function getAccount(id: string): Promise<Account> { return request<Account>(`/accounts/${id}`) }

export function createAccount(payload: AccountCreatePayload): Promise<Account> {
  return request<Account>('/accounts', { method: 'POST', data: payload })
}

export interface AccountUpdatePayload {
  name?: string
  type?: AccountType
  icon?: string
  initialBalance?: number
  currency?: string
  isDefault?: boolean
}

export function updateAccount(id: string, payload: AccountUpdatePayload): Promise<Account> {
  return request<Account>(`/accounts/${id}`, { method: 'PUT', data: payload })
}

export function deleteAccount(id: string): Promise<void> {
  return request<void>(`/accounts/${id}`, { method: 'DELETE' })
}

export function archiveAccount(id: string): Promise<Account> {
  return request<Account>(`/accounts/${id}/archive`, { method: 'POST' })
}

export function unarchiveAccount(id: string): Promise<Account> {
  return request<Account>(`/accounts/${id}/unarchive`, { method: 'POST' })
}

export type { Account, AccountCreatePayload }
