import { describe, it, expect, afterAll } from 'vitest'
import { v4 as uuid } from 'uuid'
import { register, login, getCurrentUser } from '../src/services/auth.service.js'
import { getPool, closePool } from '../src/db/pool.js'

const USERNAME = `svc_test_${uuid().slice(0, 8)}`
const PASSWORD = 'test-pass-123'

describe('auth service', () => {
  afterAll(async () => {
    // cleanup
    await getPool().query('DELETE FROM users WHERE username = ?', [USERNAME])
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
})
