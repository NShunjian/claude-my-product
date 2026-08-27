import { v4 as uuidv4 } from 'uuid'
import type { ResultSetHeader, RowDataPacket } from 'mysql2'
import { getPool } from '../db/pool.js'
import { AppError, ErrorCode } from '../constants/errors.js'
import type { Account, AccountType } from '../types/index.js'
import type { CreateAccountInput, UpdateAccountInput } from '../schemas/accounts.schema.js'

interface AccountBalanceRow extends RowDataPacket {
  uuid: string
  name: string
  type: AccountType
  icon: string
  initial_balance: number
  balance: number
  currency: string
  is_default: number
  sort_order: number
  note: string | null
  created_at: Date
}

const toAccount = (row: AccountBalanceRow): Account => ({
  id: row.uuid,
  name: row.name,
  type: row.type,
  icon: row.icon,
  initialBalance: Number(row.initial_balance),
  balance: Number(row.balance),
  currency: row.currency,
  isDefault: row.is_default === 1,
  sortOrder: row.sort_order,
  note: row.note,
  createdAt: new Date(row.created_at).toISOString(),
})

export const listAccounts = async (userId: number): Promise<Account[]> => {
  const pool = getPool()
  const [rows] = await pool.query<AccountBalanceRow[]>(
    `SELECT uuid, name, type, icon, initial_balance, balance, currency,
            is_default, sort_order, note, created_at
       FROM v_account_balance
      WHERE user_id = ?
      ORDER BY sort_order, created_at`,
    [userId],
  )
  return rows.map(toAccount)
}

export const createAccount = async (
  userId: number,
  input: CreateAccountInput,
): Promise<Account> => {
  const pool = getPool()
  // 默认账户归一：先把其它账户的 is_default 清零，再设当前为 1
  if (input.isDefault) {
    await pool.query('UPDATE accounts SET is_default = 0 WHERE user_id = ?', [userId])
  }
  // 取用户账本 id
  const [bookRows] = await pool.query<RowDataPacket[]>(
    'SELECT id FROM books WHERE owner_id = ? LIMIT 1',
    [userId],
  )
  const bookId = (bookRows[0]?.id as number) ?? null

  const uuid = uuidv4()
  await pool.query<ResultSetHeader>(
    `INSERT INTO accounts
       (uuid, user_id, book_id, name, icon, type, initial_balance, current_balance,
        currency, is_default, sort_order, note)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      uuid, userId, bookId, input.name, input.icon, input.type,
      input.initialBalance, input.initialBalance, input.currency,
      input.isDefault ? 1 : 0, input.sortOrder, input.note ?? null,
    ],
  )
  const created = await getAccountByUuid(userId, uuid)
  if (!created) {
    throw new AppError(500, ErrorCode.INTERNAL, '账户创建失败')
  }
  return created
}

export const updateAccount = async (
  userId: number,
  uuid: string,
  input: UpdateAccountInput,
): Promise<Account> => {
  const pool = getPool()
  const existing = await getAccountByUuid(userId, uuid)
  if (!existing) {
    throw new AppError(404, ErrorCode.NOT_FOUND, '账户不存在')
  }
  // 若调整 is_default 为 true，先把其它账户的默认位清零
  if (input.isDefault === true) {
    await pool.query('UPDATE accounts SET is_default = 0 WHERE user_id = ? AND uuid <> ?', [userId, uuid])
  }
  const fields: string[] = []
  const values: unknown[] = []
  for (const [key, value] of Object.entries(input)) {
    if (value === undefined) continue
    if (key === 'isDefault') {
      fields.push('is_default = ?')
      values.push(value ? 1 : 0)
    } else if (key === 'initialBalance') {
      // 调整 initial_balance 时同步调整 current_balance（差额 = 新值 - 旧值）
      const delta = Number(value) - existing.initialBalance
      fields.push('initial_balance = ?')
      values.push(Number(value))
      fields.push('current_balance = current_balance + ?')
      values.push(delta)
    } else if (key === 'sortOrder') {
      fields.push('sort_order = ?')
      values.push(Number(value))
    } else {
      const col = key.replace(/[A-Z]/g, (m) => '_' + m.toLowerCase())
      fields.push(`${col} = ?`)
      values.push(value)
    }
  }
  if (fields.length > 0) {
    values.push(userId, uuid)
    await pool.query(`UPDATE accounts SET ${fields.join(', ')} WHERE user_id = ? AND uuid = ?`, values)
  }
  const updated = await getAccountByUuid(userId, uuid)
  if (!updated) {
    throw new AppError(404, ErrorCode.NOT_FOUND, '账户不存在')
  }
  return updated
}

export const deleteAccount = async (userId: number, uuid: string): Promise<void> => {
  const pool = getPool()
  const existing = await getAccountByUuid(userId, uuid)
  if (!existing) {
    throw new AppError(404, ErrorCode.NOT_FOUND, '账户不存在')
  }
  // 校验该账户下是否有未删除的流水
  const [accountRow] = await pool.query<RowDataPacket[]>(
    'SELECT id FROM accounts WHERE uuid = ? AND user_id = ?',
    [uuid, userId],
  )
  if (!accountRow[0]) {
    throw new AppError(404, ErrorCode.NOT_FOUND, '账户不存在')
  }
  const [countRows] = await pool.query<RowDataPacket[]>(
    `SELECT COUNT(*) as c FROM records
      WHERE (account_id = ? OR to_account_id = ?) AND deleted_at IS NULL`,
    [accountRow[0].id, accountRow[0].id],
  )
  if ((countRows[0]?.c as number) > 0) {
    throw new AppError(409, ErrorCode.CONFLICT, '该账户下仍有未删除的流水，无法删除')
  }
  await pool.query('UPDATE accounts SET deleted_at = CURRENT_TIMESTAMP(3) WHERE user_id = ? AND uuid = ?', [userId, uuid])
}

const getAccountByUuid = async (userId: number, uuid: string): Promise<Account | null> => {
  const pool = getPool()
  const [rows] = await pool.query<AccountBalanceRow[]>(
    `SELECT uuid, name, type, icon, initial_balance, balance, currency,
            is_default, sort_order, note, created_at
       FROM v_account_balance
      WHERE user_id = ? AND uuid = ?`,
    [userId, uuid],
  )
  return rows[0] ? toAccount(rows[0]) : null
}