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
  created_at: Date
}

const toUser = (row: UserRow): User => ({
  id: Number(row.id),
  uuid: row.uuid,
  username: row.username,
  displayName: row.display_name,
  createdAt: new Date(row.created_at).toISOString(),
})

const issueToken = (row: UserRow): string =>
  signToken({ sub: Number(row.id), uuid: row.uuid, username: row.username } satisfies JwtPayload)

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

  // 回读完整行（保证 created_at 等由 DB 默认值填的字段拿到）
  const [rows] = await pool.query<UserRow[]>(
    'SELECT id, uuid, username, display_name, created_at FROM users WHERE id = ?',
    [insertId],
  )
  const row = rows[0]
  return { user: toUser(row), token: issueToken(row) }
}

export const login = async (input: LoginInput): Promise<{ user: User; token: string }> => {
  const pool = getPool()
  const [rows] = await pool.query<UserRow[]>(
    'SELECT id, uuid, username, password_hash, display_name, created_at FROM users WHERE username = ? LIMIT 1',
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
    'SELECT id, uuid, username, display_name, created_at FROM users WHERE uuid = ? LIMIT 1',
    [uuid],
  )
  const row = rows[0]
  if (!row) {
    throw new AppError(404, ErrorCode.INTERNAL, '用户不存在')
  }
  return toUser(row)
}
