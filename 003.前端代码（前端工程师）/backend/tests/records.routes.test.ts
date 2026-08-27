import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { v4 as uuid } from 'uuid'
import request from 'supertest'
import { createApp } from '../src/app.js'
import { getPool, closePool } from '../src/db/pool.js'

const USERNAME = `e2e_rec_${uuid().slice(0, 8)}`
const PASSWORD = 'rec-pass-123'

describe('GET/POST/PATCH/DELETE /api/records (E2E)', () => {
  const app = createApp()
  let token: string
  let accountA: string
  let accountB: string
  let firstRecordId: string

  beforeAll(async () => {
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ username: USERNAME, password: PASSWORD })
    token = reg.body.token
    const list = await request(app)
      .get('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
    accountA = list.body.items[0].id
    accountB = list.body.items[1].id
  })

  afterAll(async () => {
    const pool = getPool()
    await pool.query(
      `DELETE FROM records WHERE user_id IN (SELECT id FROM users WHERE username = ?)`,
      [USERNAME],
    )
    await pool.query(
      `DELETE a, b FROM users u
         LEFT JOIN accounts a ON a.user_id = u.id
         LEFT JOIN books b ON b.owner_id = u.id
       WHERE u.username = ?`,
      [USERNAME],
    )
    await closePool()
  })

  it('requires auth', async () => {
    const res = await request(app).get('/api/records?month=2026-08')
    expect(res.status).toBe(401)
  })

  it('creates an expense record', async () => {
    const res = await request(app)
      .post('/api/records')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'expense',
        categoryId: 'expense-餐饮',
        accountId: accountA,
        amount: 45.5,
        note: '午餐',
        recordDate: '2026-08-15',
        clientId: 'test-client-1',
      })
    expect(res.status).toBe(201)
    expect(res.body.record.amount).toBe(45.5)
    expect(res.body.record.type).toBe('expense')
    expect(res.body.record.categoryId).toBe('expense-餐饮')
    firstRecordId = res.body.record.id
  })

  it('idempotent on duplicate client_id', async () => {
    const res = await request(app)
      .post('/api/records')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'expense',
        categoryId: 'expense-餐饮',
        accountId: accountA,
        amount: 99.9,
        recordDate: '2026-08-15',
        clientId: 'test-client-1',
      })
    expect(res.status).toBe(201)
    expect(res.body.record.id).toBe(firstRecordId) // same id, no duplicate
  })

  it('creates a transfer record between two accounts', async () => {
    const res = await request(app)
      .post('/api/records')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'transfer',
        accountId: accountA,
        toAccountId: accountB,
        amount: 100,
        recordDate: '2026-08-16',
      })
    expect(res.status).toBe(201)
    expect(res.body.record.type).toBe('transfer')
    expect(res.body.record.categoryId).toBeNull()
  })

  it('rejects transfer with same from/to accounts', async () => {
    const res = await request(app)
      .post('/api/records')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'transfer',
        accountId: accountA,
        toAccountId: accountA,
        amount: 50,
        recordDate: '2026-08-17',
      })
    expect(res.status).toBe(400)
    expect(res.body.error.code).toBe('INVALID_INPUT')
  })

  it('rejects negative amount', async () => {
    const res = await request(app)
      .post('/api/records')
      .set('Authorization', `Bearer ${token}`)
      .send({
        type: 'expense',
        categoryId: 'expense-餐饮',
        accountId: accountA,
        amount: -5,
        recordDate: '2026-08-15',
      })
    expect(res.status).toBe(400)
    expect(res.body.error.code).toBe('INVALID_INPUT')
  })

  it('lists records by month filter', async () => {
    const res = await request(app)
      .get('/api/records?month=2026-08')
      .set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(200)
    expect(res.body.items.length).toBeGreaterThanOrEqual(2)
    expect(res.body.items.every((r: any) => r.recordDate.startsWith('2026-08'))).toBe(true)
  })

  it('lists records by from/to filter', async () => {
    const res = await request(app)
      .get('/api/records?from=2026-08-16&to=2026-08-31')
      .set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(200)
    expect(res.body.items.every((r: any) =>
      r.recordDate >= '2026-08-16' && r.recordDate <= '2026-08-31',
    )).toBe(true)
  })

  it('updates a record note', async () => {
    const res = await request(app)
      .patch(`/api/records/${firstRecordId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ note: '晚餐' })
    expect(res.status).toBe(200)
    expect(res.body.record.note).toBe('晚餐')
  })

  it('soft-deletes a record', async () => {
    const res = await request(app)
      .delete(`/api/records/${firstRecordId}`)
      .set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(204)

    const list = await request(app)
      .get('/api/records?month=2026-08')
      .set('Authorization', `Bearer ${token}`)
    expect(list.body.items.find((r: any) => r.id === firstRecordId)).toBeUndefined()
  })

  it('returns 404 for unknown record', async () => {
    const res = await request(app)
      .delete('/api/records/00000000-0000-0000-0000-000000000000')
      .set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(404)
    expect(res.body.error.code).toBe('NOT_FOUND')
  })
})