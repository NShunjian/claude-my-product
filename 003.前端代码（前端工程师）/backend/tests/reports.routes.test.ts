import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { v4 as uuid } from 'uuid'
import request from 'supertest'
import { createApp } from '../src/app.js'
import { getPool, closePool } from '../src/db/pool.js'

const USERNAME = `e2e_rep_${uuid().slice(0, 8)}`
const PASSWORD = 'rep-pass-123'

describe('GET /api/reports/* (E2E)', () => {
  const app = createApp()
  let token: string
  let accountId: string

  beforeAll(async () => {
    const reg = await request(app)
      .post('/api/auth/register')
      .send({ username: USERNAME, password: PASSWORD })
    token = reg.body.token
    const list = await request(app)
      .get('/api/accounts')
      .set('Authorization', `Bearer ${token}`)
    accountId = list.body.items[0].id

    // 构造 8 月份的若干条记录
    const seed: Array<Record<string, unknown>> = [
      { type: 'expense', categoryId: 'expense-餐饮', accountId, amount: 45.5,  recordDate: '2026-08-01' },
      { type: 'expense', categoryId: 'expense-餐饮', accountId, amount: 32,    recordDate: '2026-08-03' },
      { type: 'expense', categoryId: 'expense-交通', accountId, amount: 120,   recordDate: '2026-08-10' },
      { type: 'expense', categoryId: 'expense-购物', accountId, amount: 299,   recordDate: '2026-08-15' },
      { type: 'income',  categoryId: 'income-工资',  accountId, amount: 8000,  recordDate: '2026-08-01' },
      { type: 'income',  categoryId: 'income-红包',  accountId, amount: 200,   recordDate: '2026-08-15' },
      { type: 'expense', categoryId: 'expense-医疗', accountId, amount: 500,   recordDate: '2026-07-20' }, // 7 月，验证月度过滤
    ]
    for (const r of seed) {
      await request(app).post('/api/records').set('Authorization', `Bearer ${token}`).send(r)
    }
  })

  afterAll(async () => {
    const pool = getPool()
    await pool.query(`DELETE FROM records WHERE user_id IN (SELECT id FROM users WHERE username = ?)`, [USERNAME])
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
    const res = await request(app).get('/api/reports/monthly?month=2026-08')
    expect(res.status).toBe(401)
  })

  it('returns correct monthly KPIs', async () => {
    const res = await request(app)
      .get('/api/reports/monthly?month=2026-08')
      .set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(200)
    expect(res.body.month).toBe('2026-08')
    expect(res.body.totalIncome).toBe(8200)   // 8000 + 200
    expect(res.body.totalExpense).toBe(496.5) // 45.5 + 32 + 120 + 299
    expect(res.body.netSavings).toBe(7703.5)
  })

  it('returns last month data', async () => {
    const res = await request(app)
      .get('/api/reports/monthly?month=2026-08')
      .set('Authorization', `Bearer ${token}`)
    expect(res.body.lastMonth).toBeTruthy()
    expect(res.body.lastMonth.totalExpense).toBe(500) // 7 月医疗
    expect(res.body.lastMonth.totalIncome).toBe(0)
  })

  it('returns daily data covering all days of the month', async () => {
    const res = await request(app)
      .get('/api/reports/monthly?month=2026-08')
      .set('Authorization', `Bearer ${token}`)
    expect(res.body.dailyData.length).toBe(31)
    expect(res.body.dailyData[0].day).toBe(1)
    expect(res.body.dailyData[0].income).toBe(8000)
    expect(res.body.dailyData[0].expense).toBe(45.5)
    expect(res.body.dailyData[14].day).toBe(15)
    expect(res.body.dailyData[14].expense).toBe(299)
  })

  it('returns categories sorted by total desc', async () => {
    const res = await request(app)
      .get('/api/reports/monthly?month=2026-08')
      .set('Authorization', `Bearer ${token}`)
    expect(res.body.expenseByCategory.length).toBeGreaterThan(0)
    const totals = res.body.expenseByCategory.map((c: any) => c.total)
    const sortedDesc = [...totals].sort((a, b) => b - a)
    expect(totals).toEqual(sortedDesc)
    // 购物 299 > 交通 120 > 餐饮 77.5
    expect(res.body.expenseByCategory[0].categoryId).toBe('expense-购物')
    expect(res.body.expenseByCategory[0].total).toBe(299)
    expect(res.body.expenseByCategory[1].categoryId).toBe('expense-交通')
    expect(res.body.expenseByCategory[2].categoryId).toBe('expense-餐饮')
    expect(res.body.expenseByCategory[2].total).toBe(77.5)
  })

  it('rejects invalid month format', async () => {
    const res = await request(app)
      .get('/api/reports/monthly?month=2026/08')
      .set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(400)
    expect(res.body.error.code).toBe('INVALID_INPUT')
  })

  it('returns yearly report with monthly breakdown', async () => {
    const res = await request(app)
      .get('/api/reports/yearly?year=2026')
      .set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(200)
    expect(res.body.year).toBe(2026)
    expect(res.body.monthlyData.length).toBe(12)
    expect(res.body.monthlyData[7].month).toBe(8) // index 7 = August
    expect(res.body.monthlyData[7].income).toBe(8200)
    expect(res.body.monthlyData[7].expense).toBe(496.5)
    expect(res.body.monthlyData[6].month).toBe(7)
    expect(res.body.monthlyData[6].expense).toBe(500)
  })
})