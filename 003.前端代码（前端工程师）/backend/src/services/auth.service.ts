import { v4 as uuidv4 } from 'uuid'
import type { ResultSetHeader, RowDataPacket } from 'mysql2'
import { getPool } from '../db/pool.js'
import { hashPassword, verifyPassword } from '../utils/hash.js'
import { signToken } from '../utils/jwt.js'
import { AppError, ErrorCode } from '../constants/errors.js'
import type { User, JwtPayload } from '../types/index.js'
import type { RegisterInput, LoginInput } from '../schemas/auth.schema.js'

interface UserRow extends RowDataPacket {
  id: number
  uuid: string
  username: string
  display_name: string | null
  avatar: string | null
  gender: 'male' | 'female' | 'other' | null
  age: number | null
  created_at: Date
}

const toUser = (row: UserRow): User => ({
  id: Number(row.id),
  uuid: row.uuid,
  username: row.username,
  displayName: row.display_name,
  avatar: row.avatar,
  gender: row.gender,
  age: row.age != null ? Number(row.age) : null,
  createdAt: new Date(row.created_at).toISOString(),
})

const issueToken = (row: UserRow): string =>
  signToken({ sub: Number(row.id), uuid: row.uuid, username: row.username } satisfies JwtPayload)

/** 新用户注册后自动初始化的默认账户（每账户 uuid 在创建时分配，避免与 demo seed 的固定 UUID 冲突） */
const DEFAULT_ACCOUNTS = [
  { name: '微信支付', icon: '💳', type: 'wallet', isDefault: 1, sortOrder: 0 },
  { name: '支付宝',   icon: '💳', type: 'wallet', isDefault: 0, sortOrder: 1 },
  { name: '现金',     icon: '💵', type: 'cash',   isDefault: 0, sortOrder: 2 },
  { name: '银行卡',   icon: '🏦', type: 'debit',  isDefault: 0, sortOrder: 3 },
  { name: '信用卡',   icon: '💳', type: 'credit', isDefault: 0, sortOrder: 4 },
] as const

/**
 * 为新用户创建 1 个个人账本 + 5 个默认账户
 * 失败抛 AppError，但不删除已创建的用户（保持事务性不强求，依赖测试清理）
 */
const bootstrapNewUser = async (userId: number): Promise<void> => {
  const pool = getPool()
  const bookUuid = uuidv4()
  const [bookResult] = await pool.query<ResultSetHeader>(
    `INSERT INTO books (uuid, owner_id, name, type, currency, is_default, sort_order)
     VALUES (?, ?, '个人账本', 'personal', 'CNY', 1, 0)`,
    [bookUuid, userId],
  )
  const bookId = Number(bookResult.insertId)

  for (const a of DEFAULT_ACCOUNTS) {
    await pool.query(
      `INSERT INTO accounts
         (uuid, user_id, book_id, name, icon, type, initial_balance, current_balance, is_default, sort_order)
       VALUES (?, ?, ?, ?, ?, ?, 0.00, 0.00, ?, ?)`,
      [uuidv4(), userId, bookId, a.name, a.icon, a.type, a.isDefault, a.sortOrder],
    )
  }
}

export const register = async (input: RegisterInput): Promise<{ user: User; token: string }> => {
  const pool = getPool()
  const [existing] = await pool.query<UserRow[]>(
    'SELECT id FROM users WHERE username = ? LIMIT 1',
    [input.username],
  )
  if (existing.length > 0) {
    throw new AppError(409, ErrorCode.USERNAME_TAKEN, '该用户名已被注册')
  }

  const hash = await hashPassword(input.password)
  const uuid = uuidv4()
  const [result] = await pool.query<ResultSetHeader>(
    'INSERT INTO users (uuid, username, password_hash, salt, status) VALUES (?, ?, ?, ?, 1)',
    [uuid, input.username, hash, 'bcrypt'],
  )
  const insertId = Number(result.insertId)

  // 自动初始化账本 + 默认账户
  try {
    await bootstrapNewUser(insertId)
  } catch (e) {
    console.error('[register] bootstrapNewUser failed', e)
    throw e
  }

  // 回读完整行（保证 created_at 等由 DB 默认值填的字段拿到；含 profile 字段供前端资料编辑使用）
  const [rows] = await pool.query<UserRow[]>(
    'SELECT id, uuid, username, display_name, avatar, gender, age, created_at FROM users WHERE id = ?',
    [insertId],
  )
  const row = rows[0]
  return { user: toUser(row), token: issueToken(row) }
}

export const login = async (input: LoginInput): Promise<{ user: User; token: string }> => {
  const pool = getPool()
  const [rows] = await pool.query<UserRow[]>(
    'SELECT id, uuid, username, password_hash, display_name, avatar, gender, age, created_at FROM users WHERE username = ? LIMIT 1',
    [input.username],
  )
  const row = rows[0]
  if (!row) {
    throw new AppError(401, ErrorCode.INVALID_CREDENTIALS, '用户名或密码错误')
  }
  const ok = await verifyPassword(input.password, row.password_hash)
  if (!ok) {
    throw new AppError(401, ErrorCode.INVALID_CREDENTIALS, '用户名或密码错误')
  }
  // 更新最后登录时间
  await pool.query('UPDATE users SET last_login_at = CURRENT_TIMESTAMP(3) WHERE id = ?', [row.id])
  return { user: toUser(row), token: issueToken(row) }
}

export const getCurrentUser = async (uuid: string): Promise<User> => {
  const pool = getPool()
  const [rows] = await pool.query<UserRow[]>(
    'SELECT id, uuid, username, display_name, avatar, gender, age, created_at FROM users WHERE uuid = ? LIMIT 1',
    [uuid],
  )
  const row = rows[0]
  if (!row) {
    throw new AppError(404, ErrorCode.INTERNAL, '用户不存在')
  }
  return toUser(row)
}
