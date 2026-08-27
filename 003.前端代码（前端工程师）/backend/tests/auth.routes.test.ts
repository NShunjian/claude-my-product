import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { v4 as uuid } from 'uuid'
import request from 'supertest'
import { createApp } from '../src/app.js'
import { getPool, closePool } from '../src/db/pool.js'

const USERNAME = `e2e_${uuid().slice(0, 8)}`
const PASSWORD = 'e2e-pass-123'

describe('POST /api/auth/* (E2E)', () => {
  const app = createApp()

  afterAll(async () => {
    const pool = getPool()
    // 先清理子表（accounts → books）再清 user
    await pool.query(
      `DELETE a, b FROM users u
         LEFT JOIN accounts a ON a.user_id = u.id
         LEFT JOIN books b ON b.owner_id = u.id
       WHERE u.username = ?`,
      [USERNAME],
    )
    await closePool()
  })

  it('rejects invalid register input', async () => {
    const res = await request(app).post('/api/auth/register').send({ username: 'a', password: '1' })
    expect(res.status).toBe(400)
    expect(res.body.error.code).toBe('INVALID_INPUT')
  })

  it('registers a new user and bootstraps book + 5 accounts', async () => {
    const res = await request(app).post('/api/auth/register').send({ username: USERNAME, password: PASSWORD })
    expect(res.status).toBe(201)
    expect(res.body.user.username).toBe(USERNAME)
    expect(res.body.token).toMatch(/^eyJ/)

    // 验证自动初始化了账本和账户
    const pool = getPool()
    const [userRows] = await pool.query<any[]>('SELECT id FROM users WHERE username = ?', [USERNAME])
    const userId = userRows[0].id
    const [bookRows] = await pool.query<any[]>('SELECT name FROM books WHERE owner_id = ?', [userId])
    expect(bookRows.length).toBe(1)
    expect(bookRows[0].name).toBe('个人账本')

    const [acctRows] = await pool.query<any[]>(
      'SELECT name FROM accounts WHERE user_id = ? ORDER BY sort_order',
      [userId],
    )
    expect(acctRows.map((r: any) => r.name)).toEqual([
      '微信支付', '支付宝', '现金', '银行卡', '信用卡',
    ])
  })

  it('rejects duplicate username', async () => {
    const res = await request(app).post('/api/auth/register').send({ username: USERNAME, password: PASSWORD })
    expect(res.status).toBe(409)
    expect(res.body.error.code).toBe('USERNAME_TAKEN')
  })

  it('logs in with correct credentials', async () => {
    const res = await request(app).post('/api/auth/login').send({ username: USERNAME, password: PASSWORD })
    expect(res.status).toBe(200)
    expect(res.body.token).toBeDefined()
  })

  it('rejects wrong password with INVALID_CREDENTIALS', async () => {
    const res = await request(app).post('/api/auth/login').send({ username: USERNAME, password: 'wrong-pass' })
    expect(res.status).toBe(401)
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS')
  })

  it('GET /me requires token', async () => {
    const res = await request(app).get('/api/auth/me')
    expect(res.status).toBe(401)
  })

  it('GET /me with token returns user', async () => {
    const loginRes = await request(app).post('/api/auth/login').send({ username: USERNAME, password: PASSWORD })
    const token = loginRes.body.token as string
    const me = await request(app).get('/api/auth/me').set('Authorization', `Bearer ${token}`)
    expect(me.status).toBe(200)
    expect(me.body.user.username).toBe(USERNAME)
  })

  it('POST /logout acks', async () => {
    const loginRes = await request(app).post('/api/auth/login').send({ username: USERNAME, password: PASSWORD })
    const res = await request(app).post('/api/auth/logout').set('Authorization', `Bearer ${loginRes.body.token}`)
    expect(res.status).toBe(200)
    expect(res.body.ok).toBe(true)
  })
})
