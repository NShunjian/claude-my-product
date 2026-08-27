import { describe, it, expect, afterAll } from 'vitest'
import request from 'supertest'
import { createApp } from '../src/app.js'
import { closePool } from '../src/db/pool.js'

describe('GET /api/categories', () => {
  const app = createApp()

  afterAll(async () => {
    await closePool()
  })

  it('returns all categories when no type filter', async () => {
    const res = await request(app).get('/api/categories')
    expect(res.status).toBe(200)
    expect(Array.isArray(res.body.items)).toBe(true)
    expect(res.body.items.length).toBe(14) // 9 expense + 5 income
    const types = new Set(res.body.items.map((c: any) => c.type))
    expect(types.has('expense')).toBe(true)
    expect(types.has('income')).toBe(true)
  })

  it('returns only expense categories when type=expense', async () => {
    const res = await request(app).get('/api/categories?type=expense')
    expect(res.status).toBe(200)
    expect(res.body.items.length).toBe(9)
    expect(res.body.items.every((c: any) => c.type === 'expense')).toBe(true)
  })

  it('returns only income categories when type=income', async () => {
    const res = await request(app).get('/api/categories?type=income')
    expect(res.status).toBe(200)
    expect(res.body.items.length).toBe(5)
    expect(res.body.items.every((c: any) => c.type === 'income')).toBe(true)
  })

  it('rejects invalid type', async () => {
    const res = await request(app).get('/api/categories?type=invalid')
    expect(res.status).toBe(400)
    expect(res.body.error.code).toBe('INVALID_INPUT')
  })

  it('returns categories with required fields', async () => {
    const res = await request(app).get('/api/categories')
    const sample = res.body.items[0]
    expect(sample).toHaveProperty('id')
    expect(sample).toHaveProperty('type')
    expect(sample).toHaveProperty('name')
    expect(sample).toHaveProperty('icon')
    expect(sample).toHaveProperty('color')
  })
})