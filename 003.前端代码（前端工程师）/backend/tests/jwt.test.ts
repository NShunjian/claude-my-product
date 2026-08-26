import { describe, it, expect } from 'vitest'
import { signToken, verifyToken } from '../src/utils/jwt.js'
import type { JwtPayload } from '../src/types/index.js'

describe('jwt utils', () => {
  const payload: JwtPayload = { sub: 1, uuid: 'u-1', username: 'alice' }

  it('signs and verifies', () => {
    const token = signToken(payload)
    expect(typeof token).toBe('string')
    expect(verifyToken(token)).toMatchObject(payload)
  })

  it('throws on bad token', () => {
    expect(() => verifyToken('not-a-real-token')).toThrow()
  })
})
