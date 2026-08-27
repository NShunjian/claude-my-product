import { v4 as uuidv4 } from 'uuid'
import type { ResultSetHeader, RowDataPacket } from 'mysql2'
import { getPool } from '../db/pool.js'
import { AppError, ErrorCode } from '../constants/errors.js'
import type { Record, RecordType, RecordSource } from '../types/index.js'
import type {
  CreateRecordInput,
  UpdateRecordInput,
  ListRecordsQuery,
} from '../schemas/records.schema.js'

interface RecordRow extends RowDataPacket {
  uuid: string
  type: RecordType
  category_uuid: string | null
  account_uuid: string
  to_account_uuid: string | null
  amount: number
  currency: string
  note: string | null
  record_date: Date
  source: RecordSource
  created_at: Date
  updated_at: Date
}

/** 安全格式化 DATE 列（mysql2 返回 Date 对象时勿做 UTC 转换） */
const fmtDateOnly = (v: string | Date): string => {
  if (typeof v === 'string') return v.length >= 10 ? v.slice(0, 10) : v
  const y = v.getFullYear()
  const m = String(v.getMonth() + 1).padStart(2, '0')
  const d = String(v.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

const toRecord = (row: RecordRow): Record => ({
  id: row.uuid,
  type: row.type,
  categoryId: row.category_uuid,
  accountId: row.account_uuid,
  toAccountId: row.to_account_uuid,
  amount: Number(row.amount),
  currency: row.currency,
  note: row.note,
  recordDate: fmtDateOnly(row.record_date),
  source: row.source,
  createdAt: new Date(row.created_at).toISOString(),
  updatedAt: new Date(row.updated_at).toISOString(),
})

const BASE_SELECT = `
  SELECT r.uuid, r.type,
         c.uuid AS category_uuid,
         a.uuid AS account_uuid,
         ta.uuid AS to_account_uuid,
         r.amount, r.currency, r.note, r.record_date, r.source,
         r.created_at, r.updated_at
    FROM records r
    LEFT JOIN categories c ON c.id = r.category_id
    LEFT JOIN accounts   a ON a.id = r.account_id
    LEFT JOIN accounts  ta ON ta.id = r.to_account_id
`

const assertOwnedAccount = async (
  userId: number,
  uuid: string,
): Promise<number> => {
  const pool = getPool()
  const [rows] = await pool.query<RowDataPacket[]>(
    'SELECT id FROM accounts WHERE uuid = ? AND user_id = ? AND deleted_at IS NULL',
    [uuid, userId],
  )
  if (!rows[0]) {
    throw new AppError(400, ErrorCode.INVALID_INPUT, '账户不存在或不属于当前用户')
  }
  return rows[0].id as number
}

const resolveCategoryId = async (uuid: string | null | undefined): Promise<number | null> => {
  if (!uuid) return null
  const pool = getPool()
  const [rows] = await pool.query<RowDataPacket[]>(
    'SELECT id FROM categories WHERE uuid = ? AND is_active = 1',
    [uuid],
  )
  if (!rows[0]) {
    throw new AppError(400, ErrorCode.INVALID_INPUT, '分类不存在')
  }
  return rows[0].id as number
}

export const listRecords = async (
  userId: number,
  query: ListRecordsQuery,
): Promise<Record[]> => {
  const pool = getPool()
  const conds: string[] = ['r.user_id = ?', 'r.deleted_at IS NULL']
  const params: unknown[] = [userId]
  if (query.month) {
    const [y, m] = query.month.split('-')
    const lastDay = new Date(Number(y), Number(m), 0).getDate()
    conds.push('r.record_date BETWEEN ? AND ?')
    params.push(`${query.month}-01`, `${query.month}-${String(lastDay).padStart(2, '0')}`)
  }
  if (query.from) { conds.push('r.record_date >= ?'); params.push(query.from) }
  if (query.to)   { conds.push('r.record_date <= ?'); params.push(query.to) }
  if (query.type) { conds.push('r.type = ?');        params.push(query.type) }
  if (query.categoryId) { conds.push('c.uuid = ?');  params.push(query.categoryId) }
  if (query.accountId)  { conds.push('(a.uuid = ? OR ta.uuid = ?)'); params.push(query.accountId, query.accountId) }
  const [rows] = await pool.query<RecordRow[]>(
    `${BASE_SELECT} WHERE ${conds.join(' AND ')} ORDER BY r.record_date DESC, r.id DESC`,
    params,
  )
  return rows.map(toRecord)
}

export const createRecord = async (
  userId: number,
  input: CreateRecordInput,
): Promise<Record> => {
  const pool = getPool()
  // 离线去重
  if (input.clientId) {
    const [existing] = await pool.query<RowDataPacket[]>(
      'SELECT uuid FROM records WHERE user_id = ? AND client_id = ? LIMIT 1',
      [userId, input.clientId],
    )
    if (existing[0]) {
      return (await getRecordByUuid(userId, existing[0].uuid as string))!
    }
  }
  const accountId = await assertOwnedAccount(userId, input.accountId)
  const toAccountId = input.type === 'transfer' && input.toAccountId
    ? await assertOwnedAccount(userId, input.toAccountId)
    : null
  const categoryId = input.type !== 'transfer'
    ? await resolveCategoryId(input.categoryId)
    : null

  const uuid = uuidv4()
  await pool.query<ResultSetHeader>(
    `INSERT INTO records
       (uuid, user_id, book_id, type, category_id, account_id, to_account_id,
        amount, currency, note, record_date, source, client_id)
     VALUES (
       ?, ?, (SELECT id FROM books WHERE owner_id = ? LIMIT 1),
       ?, ?, ?, ?,
       ?, 'CNY', ?, ?, 'manual', ?
     )`,
    [
      uuid, userId, userId,
      input.type, categoryId, accountId, toAccountId,
      input.amount, input.note ?? null, input.recordDate, input.clientId ?? null,
    ],
  )
  const created = await getRecordByUuid(userId, uuid)
  if (!created) throw new AppError(500, ErrorCode.INTERNAL, '记录创建失败')
  return created
}

export const updateRecord = async (
  userId: number,
  uuid: string,
  input: UpdateRecordInput,
): Promise<Record> => {
  const pool = getPool()
  const existing = await getRecordByUuid(userId, uuid)
  if (!existing) throw new AppError(404, ErrorCode.NOT_FOUND, '记录不存在')

  const fields: string[] = []
  const values: unknown[] = []
  const setField = (col: string, val: unknown): void => {
    fields.push(`${col} = ?`)
    values.push(val)
  }
  if (input.amount !== undefined) setField('amount', input.amount)
  if (input.note !== undefined) setField('note', input.note)
  if (input.recordDate !== undefined) setField('record_date', input.recordDate)
  if (input.accountId !== undefined) {
    const aid = await assertOwnedAccount(userId, input.accountId)
    setField('account_id', aid)
  }
  if (input.toAccountId !== undefined) {
    const taid = input.toAccountId ? await assertOwnedAccount(userId, input.toAccountId) : null
    setField('to_account_id', taid)
  }
  if (input.categoryId !== undefined) {
    const cid = await resolveCategoryId(input.categoryId)
    setField('category_id', cid)
  }
  if (fields.length > 0) {
    values.push(userId, uuid)
    await pool.query(`UPDATE records SET ${fields.join(', ')} WHERE user_id = ? AND uuid = ?`, values)
  }
  const updated = await getRecordByUuid(userId, uuid)
  if (!updated) throw new AppError(404, ErrorCode.NOT_FOUND, '记录不存在')
  return updated
}

export const deleteRecord = async (userId: number, uuid: string): Promise<void> => {
  const pool = getPool()
  const [result] = await pool.query<ResultSetHeader>(
    'UPDATE records SET deleted_at = CURRENT_TIMESTAMP(3) WHERE user_id = ? AND uuid = ? AND deleted_at IS NULL',
    [userId, uuid],
  )
  if (result.affectedRows === 0) {
    throw new AppError(404, ErrorCode.NOT_FOUND, '记录不存在或已删除')
  }
}

const getRecordByUuid = async (userId: number, uuid: string): Promise<Record | null> => {
  const pool = getPool()
  const [rows] = await pool.query<RecordRow[]>(
    `${BASE_SELECT} WHERE r.user_id = ? AND r.uuid = ? AND r.deleted_at IS NULL`,
    [userId, uuid],
  )
  return rows[0] ? toRecord(rows[0]) : null
}