import { describe, it, expect, afterAll } from 'vitest'
import { v4 as uuid } from 'uuid'
import { register, login, getCurrentUser } from '../src/services/auth.service.js'
import { getPool, closePool } from '../src/db/pool.js'

const USERNAME = `svc_test_${uuid().slice(0, 8)}`
const PASSWORD = 'test-pass-123'

describe('auth service', () => {
  afterAll(async () => {
    // cleanup：按 FK 反向顺序删（accounts → books → users），避免 fk_books_owner RESTRICT 报错
    const pool = getPool()
    await pool.query(
      `DELETE FROM accounts WHERE user_id IN (SELECT id FROM users WHERE username = ?)`,
      [USERNAME],
    )
    await pool.query(
      `DELETE FROM books WHERE owner_id IN (SELECT id FROM users WHERE username = ?)`,
      [USERNAME],
    )
    await pool.query('DELETE FROM users WHERE username = ?', [USERNAME])
    await closePool()
  })

  it('register creates a user and returns token', async () => {
    const { user, token } = await register({ username: USERNAME, password: PASSWORD })
    expect(user.username).toBe(USERNAME)
    expect(user.id).toBeGreaterThan(0)
    expect(token).toMatch(/^eyJ/)
  })

  it('login with correct password succeeds', async () => {
    const { user } = await login({ username: USERNAME, password: PASSWORD })
    expect(user.username).toBe(USERNAME)
  })

  it('login with wrong password throws INVALID_CREDENTIALS', async () => {
    await expect(login({ username: USERNAME, password: 'wrong-pw-1' })).rejects.toMatchObject({
      status: 401,
      code: 'INVALID_CREDENTIALS',
    })
  })

  it('login with unknown user throws INVALID_CREDENTIALS', async () => {
    await expect(login({ username: 'no-s-huch-user', password: 'whatever' })).rejects.toMatchObject({
      status: 401,
      code: 'INVALID_CREDENTIALS',
    })
  })

  it('register with existing username throws USERNAME_TAKEN', async () => {
    await expect(register({ username: USERNAME, password: PASSWORD })).rejects.toMatchObject({
      status: 409,
      code: 'USERNAME_TAKEN',
    })
  })

  it('getCurrentUser returns the user by uuid', async () => {
    const { user } = await login({ username: USERNAME, password: PASSWORD })
    const fetched = await getCurrentUser(user.uuid)
    expect(fetched.username).toBe(USERNAME)
  })

  it('register returns user with all profile fields (avatar/gender/age may be null)', async () => {
    const freshUser = `sf_${uuid().slice(0, 8)}`
    const { user } = await register({ username: freshUser, password: PASSWORD })
    expect(user).toHaveProperty('avatar')
    expect(user.avatar).toBeNull()
    expect(user).toHaveProperty('gender')
    expect(user.gender).toBeNull()
    expect(user).toHaveProperty('age')
    expect(user.age).toBeNull()
    expect(user).toHaveProperty('displayName')
    expect(user.displayName).toBeNull()
    expect(user).toHaveProperty('createdAt')
    expect(typeof user.createdAt).toBe('string')
    expect(new Date(user.createdAt).toString()).not.toBe('Invalid Date')
    // 清理该 case 单独建的用户
    const pool = getPool()
    const [u] = await pool.query<any[]>(`SELECT id FROM users WHERE username = ?`, [freshUser])
    if (u[0]) {
      await pool.query(`DELETE FROM accounts WHERE user_id = ?`, [u[0].id])
      await pool.query(`DELETE FROM books WHERE owner_id = ?`, [u[0].id])
      await pool.query(`DELETE FROM users WHERE id = ?`, [u[0].id])
    }
  })

  it('getCurrentUser exposes all profile fields after updateProfile-style write', async () => {
    const pool = getPool()
    // 直接 UPDATE 模拟「前端资料编辑后保存」,然后 getCurrentUser 应读到
    const [u] = await pool.query<any[]>(`SELECT id, uuid FROM users WHERE username = ? LIMIT 1`, [USERNAME])
    await pool.query(
      `UPDATE users SET display_name = ?, avatar = ?, gender = ?, age = ? WHERE id = ?`,
      ['小张同学', 'https://example.com/a.png', 'female', 28, u[0].id],
    )
    const { user: fresh } = await login({ username: USERNAME, password: PASSWORD })
    expect(fresh.displayName).toBe('小张同学')
    expect(fresh.avatar).toBe('https://example.com/a.png')
    expect(fresh.gender).toBe('female')
    expect(fresh.age).toBe(28)

    const fetched = await getCurrentUser(fresh.uuid)
    expect(fetched.displayName).toBe('小张同学')
    expect(fetched.avatar).toBe('https://example.com/a.png')
    expect(fetched.gender).toBe('female')
    expect(fetched.age).toBe(28)
  })
})
