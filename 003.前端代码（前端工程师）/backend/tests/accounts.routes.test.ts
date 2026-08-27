import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { v4 as uuid } from 'uuid'
import request from 'supertest'
import { createApp } from '../src/app.js'
import { getPool, closePool } from '../src/db/pool.js'

const USERNAME = `e2e_acct_${uuid().slice(0, 8)}`
const PASSWORD = 'acct-pass-123'

describe('GET/POST/PATCH/DELETE /api/accounts (E2E)', () => {
  const app = createApp()
  let token: string
  let firstAccountId: string

  beforeAll(async () => {
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ username: USERNAME, password: PASSWORD })
    token = reg.body.token
    // 注册时已自动建 5 个默认账户
    const list = await request(app)
      .get('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
    firstAccountId = list.body.items[0].id
  })

  afterAll(async () => {
    const pool = getPool()
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
    const res = await request(app).get('/api/accounts')
    expect(res.status).toBe(401)
  })

  it('lists bootstrapped accounts (5 of them)', async () => {
    const res = await request(app)
      .get('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(200)
    expect(res.body.items.length).toBe(5)
    expect(res.body.items[0]).toHaveProperty('balance')
    expect(res.body.items[0].balance).toBe(0)
  })

  it('creates a new account', async () => {
    const res = await request(app)
      .post('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
      .send({
        name: '活期存款',
        type: 'debit',
        icon: '🏦',
        initialBalance: 1000,
        isDefault: false,
      })
    expect(res.status).toBe(201)
    expect(res.body.account.name).toBe('活期存款')
    expect(res.body.account.balance).toBe(1000)
    expect(res.body.account.currency).toBe('CNY')
  })

  it('rejects create with empty name', async () => {
    const res = await request(app)
      .post('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: '', type: 'cash' })
    expect(res.status).toBe(400)
    expect(res.body.error.code).toBe('INVALID_INPUT')
  })

  it('updates an account', async () => {
    const res = await request(app)
      .patch(`/api/accounts/${firstAccountId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ name: '微信（已改名）' })
    expect(res.status).toBe(200)
    expect(res.body.account.name).toBe('微信（已改名）')
  })

  it('returns 404 for unknown account update', async () => {
    const res = await request(app)
      .patch('/api/accounts/00000000-0000-0000-0000-000000000000')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: 'X' })
    expect(res.status).toBe(404)
    expect(res.body.error.code).toBe('NOT_FOUND')
  })

  it('soft-deletes an empty account', async () => {
    // 创建一个无流水账户并删除
    const create = await request(app)
      .post('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
      .send({ name: '临时账户', type: 'cash' })
    const del = await request(app)
      .delete(`/api/accounts/${create.body.account.id}`)
      .set('Authorization', `Bearer ${token}`)
    expect(del.status).toBe(204)

    // 列表中不应再出现
    const list = await request(app)
      .get('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
    expect(list.body.items.find((a: any) => a.id === create.body.account.id)).toBeUndefined()
  })
})