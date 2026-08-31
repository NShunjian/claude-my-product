import { request } from './http'

export type RecordType = 'expense' | 'income' | 'transfer'
export type RecordSource = 'manual' | 'import' | 'ocr' | 'auto' | 'sync'

export interface Record {
  id: string
  type: RecordType
  categoryId: string | null
  accountId: string
  toAccountId: string | null
  amount: number
  currency: string
  note: string | null
  /** YYYY-MM-DD（本地时区） */
  recordDate: string
  source: RecordSource
  clientId: string | null
  createdAt: string
  updatedAt: string
}

export interface ListRecordsResponse {
  items: Record[]
}

export interface RecordEnvelope {
  record: Record
}

export interface ListRecordsParams {
  /** YYYY-MM */
  month?: string
  /** YYYY-MM-DD */
  from?: string
  /** YYYY-MM-DD */
  to?: string
  type?: RecordType
  categoryId?: string
  accountId?: string
  /** V1.1:缺省走用户所有账本 */
  bookId?: string
}

type CreateInput =
  | {
      type: 'expense'
      categoryId: string
      accountId: string
      amount: number
      recordDate: string
      note?: string
      clientId?: string
      bookId?: string
    }
  | {
      type: 'income'
      categoryId: string
      accountId: string
      amount: number
      recordDate: string
      note?: string
      clientId?: string
      bookId?: string
    }
  | {
      type: 'transfer'
      accountId: string
      toAccountId: string
      amount: number
      recordDate: string
      note?: string
      clientId?: string
      bookId?: string
    }

export type UpdateRecordInput = Partial<{
  categoryId: string | null
  accountId: string
  toAccountId: string | null
  amount: number
  recordDate: string
  note: string | null
}>

function buildQuery(p: ListRecordsParams): string {
  const sp = new URLSearchParams()
  if (p.month) sp.set('month', p.month)
  if (p.from) sp.set('from', p.from)
  if (p.to) sp.set('to', p.to)
  if (p.type) sp.set('type', p.type)
  if (p.categoryId) sp.set('categoryId', p.categoryId)
  if (p.accountId) sp.set('accountId', p.accountId)
  if (p.bookId) sp.set('bookId', p.bookId)
  const s = sp.toString()
  return s ? `?${s}` : ''
}

export async function listRecords(params: ListRecordsParams = {}): Promise<Record[]> {
  const res = await request<ListRecordsResponse>(`/api/records${buildQuery(params)}`)
  return res.items
}

export async function createRecord(input: CreateInput): Promise<Record> {
  const res = await request<RecordEnvelope>('/api/records', {
    method: 'POST',
    data: input,
  })
  return res.record
}

export async function updateRecord(id: string, input: UpdateRecordInput): Promise<Record> {
  const res = await request<RecordEnvelope>(`/api/records/${id}`, {
    method: 'PATCH',
    data: input,
  })
  return res.record
}

export async function deleteRecord(id: string): Promise<void> {
  await request<{ ok: true }>(`/api/records/${id}`, { method: 'DELETE' })
}
