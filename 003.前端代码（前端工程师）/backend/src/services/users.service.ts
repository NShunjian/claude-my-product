import type { ResultSetHeader, RowDataPacket } from 'mysql2'
import { getPool } from '../db/pool.js'
import { hashPassword, verifyPassword } from '../utils/hash.js'
import { AppError, ErrorCode } from '../constants/errors.js'
import type { UpdateProfileInput, ChangePasswordInput } from '../schemas/users.schema.js'

export interface UserProfile {
  id: number
  uuid: string
  username: string
  displayName: string | null
  avatar: string | null
  gender: 'male' | 'female' | 'other' | null
  age: number | null
  createdAt: string
}

interface ProfileRow extends RowDataPacket {
  id: number
  uuid: string
  username: string
  display_name: string | null
  avatar: string | null
  gender: 'male' | 'female' | 'other' | null
  age: number | null
  created_at: Date
}

const toProfile = (row: ProfileRow): UserProfile => ({
  id: Number(row.id),
  uuid: row.uuid,
  username: row.username,
  displayName: row.display_name,
  avatar: row.avatar,
  gender: row.gender,
  age: row.age === null ? null : Number(row.age),
  createdAt: new Date(row.created_at).toISOString(),
})

export const getProfile = async (uuid: string): Promise<UserProfile> => {
  const pool = getPool()
  const [rows] = await pool.query<ProfileRow[]>(
    `SELECT id, uuid, username, display_name, avatar, gender, age, created_at
       FROM users WHERE uuid = ? AND deleted_at IS NULL`,
    [uuid],
  )
  if (!rows[0]) {
    throw new AppError(404, ErrorCode.NOT_FOUND, '用户不存在')
  }
  return toProfile(rows[0])
}

export const updateProfile = async (
  uuid: string,
  input: UpdateProfileInput,
): Promise<UserProfile> => {
  const pool = getPool()
  // 转 camelCase -> snake_case
  const fields: string[] = []
  const values: unknown[] = []
  if (input.displayName !== undefined) { fields.push('display_name = ?'); values.push(input.displayName) }
  if (input.avatar !== undefined)       { fields.push('avatar = ?');       values.push(input.avatar) }
  if (input.gender !== undefined)       { fields.push('gender = ?');       values.push(input.gender) }
  if (input.age !== undefined)          { fields.push('age = ?');          values.push(input.age) }
  if (fields.length === 0) {
    return getProfile(uuid)
  }
  values.push(uuid)
  await pool.query<ResultSetHeader>(
    `UPDATE users SET ${fields.join(', ')} WHERE uuid = ? AND deleted_at IS NULL`,
    values,
  )
  return getProfile(uuid)
}

export const changePassword = async (
  uuid: string,
  input: ChangePasswordInput,
): Promise<void> => {
  const pool = getPool()
  const [rows] = await pool.query<RowDataPacket[]>(
    'SELECT id, password_hash FROM users WHERE uuid = ? AND deleted_at IS NULL',
    [uuid],
  )
  if (!rows[0]) {
    throw new AppError(404, ErrorCode.NOT_FOUND, '用户不存在')
  }
  const ok = await verifyPassword(input.oldPassword, rows[0].password_hash as string)
  if (!ok) {
    throw new AppError(401, ErrorCode.INVALID_CREDENTIALS, '旧密码错误')
  }
  const newHash = await hashPassword(input.newPassword)
  await pool.query<ResultSetHeader>(
    'UPDATE users SET password_hash = ? WHERE id = ?',
    [newHash, rows[0].id],
  )
}