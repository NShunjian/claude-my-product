import { describe, it, expect } from 'vitest'
import { getPool, closePool } from '../src/db/pool.js'

describe('MySQL pool', () => {
  it('returns a working pool', async () => {
    const pool = getPool()
    const [rows] = await pool.query('SELECT 1 AS one')
    expect((rows as any)[0].one).toBe(1)
    await closePool()
  })

  it('returns the same singleton across calls', () => {
    const a = getPool()
    const b = getPool()
    expect(a).toBe(b)
  })
})
