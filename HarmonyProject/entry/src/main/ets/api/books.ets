/**
 * 账本 API:对齐 uniapp api/books.ts 1:1。
 */
import { request } from './http'
import type { Book, BookCreatePayload, BookUpdatePayload, BookMember, BookRole } from '../model/Types'

export interface InviteMemberPayload { username: string; role: BookRole }
export interface UpdateMemberRolePayload { role: BookRole }

export function listBooks(): Promise<Book[]> { return request<Book[]>('/books') }
export function createBook(payload: BookCreatePayload): Promise<Book> {
  return request<Book>('/books', { method: 'POST', data: payload })
}
export function updateBook(uuid: string, payload: BookUpdatePayload): Promise<Book> {
  return request<Book>(`/books/${uuid}`, { method: 'PUT', data: payload })
}
export function deleteBook(uuid: string): Promise<void> {
  return request<void>(`/books/${uuid}`, { method: 'DELETE' })
}
export function listMembers(uuid: string): Promise<BookMember[]> {
  return request<BookMember[]>(`/books/${uuid}/members`)
}
export function inviteMember(uuid: string, username: string, role: BookRole): Promise<BookMember> {
  const p: InviteMemberPayload = { username: username, role: role }
  return request<BookMember>(`/books/${uuid}/members`, { method: 'POST', data: p })
}
export function updateMemberRole(uuid: string, userId: string, role: BookRole): Promise<BookMember> {
  const p: UpdateMemberRolePayload = { role: role }
  return request<BookMember>(`/books/${uuid}/members/${userId}`, { method: 'PUT', data: p })
}
export function removeMember(uuid: string, userId: string): Promise<void> {
  return request<void>(`/books/${uuid}/members/${userId}`, { method: 'DELETE' })
}
export function leaveBook(uuid: string): Promise<void> {
  return request<void>(`/books/${uuid}/leave`, { method: 'POST' })
}

export type { Book, BookCreatePayload, BookUpdatePayload, BookMember, BookRole, BookType } from '../model/Types'
