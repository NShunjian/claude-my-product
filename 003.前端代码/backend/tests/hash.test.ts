import { describe, it, expect } from 'vitest'
import { hashPassword, verifyPassword } from '../src/utils/hash.js'

describe('hash utils', () => {
  it('hashes and verifies the same password', async () => {
    const hash = await hashPassword('hello-world-123')
    expect(hash).not.toBe('hello-world-123')
    expect(hash.length).toBeGreaterThan(40)
    expect(await verifyPassword('hello-world-123', hash)).toBe(true)
  })

  it('rejects wrong password', async () => {
    const hash = await hashPassword('correct-horse')
    expect(await verifyPassword('wrong-horse', hash)).toBe(false)
  })
})
