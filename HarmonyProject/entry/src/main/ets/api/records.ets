/**
 * 流水 API:对齐 uniapp api/records.ts 1:1。
 */
import { request } from './http'
import type { Record, RecordCreatePayload, RecordUpdatePayload } from '../model/Types'

export interface ListRecordsResponse {
  items: Record[]
}

export interface ListRecordsParams {
  month?: string // YYYY-MM
  bookId: string
  all?: boolean
}

export async function listRecords(params: ListRecordsParams): Promise<Record[]> {
  const parts: string[] = []
  if (params.bookId) parts.push(`bookId=${encodeURIComponent(params.bookId)}`)
  if (params.month) parts.push(`month=${encodeURIComponent(params.month)}`)
  if (params.all) parts.push('all=true')
  const q = parts.length ? `?${parts.join('&')}` : ''
  const res: ListRecordsResponse = await request<ListRecordsResponse>(`/records${q}`)
  return res.items
}

export function getRecord(id: string): Promise<Record> { return request<Record>(`/records/${id}`) }

export function createRecord(payload: RecordCreatePayload): Promise<Record> {
  return request<Record>('/records', { method: 'POST', data: payload })
}

export function updateRecord(id: string, payload: RecordUpdatePayload): Promise<Record> {
  return request<Record>(`/records/${id}`, { method: 'PUT', data: payload })
}

export function deleteRecord(id: string): Promise<void> {
  return request<void>(`/records/${id}`, { method: 'DELETE' })
}

export type { Record, RecordCreatePayload, RecordUpdatePayload, RecordType } from '../model/Types'
