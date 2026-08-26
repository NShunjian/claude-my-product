import { describe, it, expect, beforeEach, vi } from 'vitest'

describe('env loader', () => {
  beforeEach(() => {
    vi.resetModules()
    delete process.env.PORT
    delete process.env.DB_HOST
    delete process.env.DB_USER
    delete process.env.DB_PASSWORD
    delete process.env.DB_NAME
    delete process.env.JWT_SECRET
  })

  it('throws when JWT_SECRET is missing', async () => {
    await expect(import('../src/config/env.js')).rejects.toThrow(/JWT_SECRET/)
  })

  it('throws when DB_HOST is missing', async () => {
    process.env.JWT_SECRET = 'a'.repeat(32)
    await expect(import('../src/config/env.js')).rejects.toThrow(/DB_HOST/)
  })

  it('parses BCRYPT_COST as integer with default 12', async () => {
    process.env.JWT_SECRET = 'a'.repeat(32)
    process.env.DB_HOST = 'localhost'
    process.env.DB_USER = 'root'
    process.env.DB_PASSWORD = '123456'
    process.env.DB_NAME = 'qingzhang'
    const { env } = await import('../src/config/env.js')
    expect(env.BCRYPT_COST).toBe(12)
    expect(env.PORT).toBe(4000)
    expect(env.JWT_EXPIRES_IN).toBe('7d')
  })
})
