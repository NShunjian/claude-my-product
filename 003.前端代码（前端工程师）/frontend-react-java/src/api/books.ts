import { request } from '../lib/api'

export type BookType = 'personal' | 'shared' | 'business'
export type BookRole = 'owner' | 'admin' | 'editor' | 'viewer'

export interface Book {
  uuid: string
  name: string
  description: string | null
  type: BookType
  currency: string
  isDefault: boolean
  isArchived: boolean
  /** 当前用户在该账本的角色;仅 owner / admin / editor / viewer 之一 */
  role: BookRole
  /** 拥有者 uuid;非本人账本也会有 */
  ownerUuid: string
  createdAt: string
  updatedAt: string
}

export interface BookMember {
  userUuid: string
  username: string
  displayName: string | null
  avatar: string | null
  role: BookRole
  joinedAt: string
  invitedByUuid: string | null
}

export interface ListBooksResponse {
  items: Book[]
}

export interface BookEnvelope {
  book: Book
}

export interface ListMembersResponse {
  items: BookMember[]
}

export interface MemberEnvelope {
  member: BookMember
}

export interface CreateBookInput {
  name: string
  description?: string
  type?: BookType
  currency?: string
}

export interface UpdateBookInput {
  name?: string
  description?: string | null
  type?: BookType
  isArchived?: boolean
}

export interface AddMemberInput {
  username: string
  role: Exclude<BookRole, 'owner'>
}

export interface UpdateMemberRoleInput {
  role: Exclude<BookRole, 'owner'>
}

// ===== Books =====

export async function listBooks(): Promise<Book[]> {
  const res = await request<ListBooksResponse>('/api/books')
  return res.items
}

export async function getBook(uuid: string): Promise<Book> {
  const res = await request<BookEnvelope>(`/api/books/${encodeURIComponent(uuid)}`)
  return res.book
}

export async function createBook(input: CreateBookInput): Promise<Book> {
  const res = await request<BookEnvelope>('/api/books', {
    method: 'POST',
    body: JSON.stringify(input),
  })
  return res.book
}

export async function updateBook(uuid: string, input: UpdateBookInput): Promise<Book> {
  const res = await request<BookEnvelope>(`/api/books/${encodeURIComponent(uuid)}`, {
    method: 'PATCH',
    body: JSON.stringify(input),
  })
  return res.book
}

export async function deleteBook(uuid: string): Promise<void> {
  await request<{ ok: true }>(`/api/books/${encodeURIComponent(uuid)}`, { method: 'DELETE' })
}

/**
 * 设为当前用户「活跃账本」。后端不动 DB(简化决策:localStorage 持久化)。
 * 这里仍发请求是为将来切换到 DB 列做兼容;目前后端对 owner 写 is_default,对其他角色直接 200。
 */
export async function setDefaultBook(uuid: string): Promise<Book> {
  const res = await request<BookEnvelope>(`/api/books/${encodeURIComponent(uuid)}/default`, {
    method: 'POST',
  })
  return res.book
}

// ===== Members =====

export async function listMembers(bookUuid: string): Promise<BookMember[]> {
  const res = await request<ListMembersResponse>(
    `/api/books/${encodeURIComponent(bookUuid)}/members`,
  )
  return res.items
}

export async function addMember(bookUuid: string, input: AddMemberInput): Promise<BookMember> {
  const res = await request<MemberEnvelope>(
    `/api/books/${encodeURIComponent(bookUuid)}/members`,
    { method: 'POST', body: JSON.stringify(input) },
  )
  return res.member
}

export async function updateMemberRole(
  bookUuid: string,
  userUuid: string,
  input: UpdateMemberRoleInput,
): Promise<BookMember> {
  const res = await request<MemberEnvelope>(
    `/api/books/${encodeURIComponent(bookUuid)}/members/${encodeURIComponent(userUuid)}`,
    { method: 'PATCH', body: JSON.stringify(input) },
  )
  return res.member
}

export async function removeMember(bookUuid: string, userUuid: string): Promise<void> {
  await request<{ ok: true }>(
    `/api/books/${encodeURIComponent(bookUuid)}/members/${encodeURIComponent(userUuid)}`,
    { method: 'DELETE' },
  )
}
