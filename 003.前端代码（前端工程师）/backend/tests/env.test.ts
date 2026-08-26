import { describe, it, expect, beforeEach } from 'vitest'

describe('env loader', () => {
  beforeEach(() => {
    delete process.env.PORT
    delete process.env.DB_HOST
    delete process.env.JWT_SECRET
  })

  it('throws when JWT_SECRET is missing', async () => {
    await expect(import('../src/config/env.js')).rejects.toThrow(/JWT_SECRET/)
  })

  it('throws when DB_HOST is missing', async () => {
    process.env.JWT_SECRET = 'a'.repeat(32)
    await expect(import('../src/config/env.js?missing=db')).rejects.toThrow(/DB_HOST/)
  })

  it('parses BCRYPT_COST as integer with default 12', async () => {
    process.env.JWT_SECRET = 'a'.repeat(32)
    process.env.DB_HOST = 'localhost'
    const { env } = await import(`../src/config/env.js?ok=${Date.now()}`)
    expect(env.BCRYPT_COST).toBe(12)
    expect(env.PORT).toBe(4000)
    expect(env.JWT_EXPIRES_IN).toBe('7d')
  })
})
