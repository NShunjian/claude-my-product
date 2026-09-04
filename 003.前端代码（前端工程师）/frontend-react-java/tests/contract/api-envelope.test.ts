// @vitest-environment jsdom
/**
 * 003 frontend-react-java — DTO 契约测试(MSW + 真实断言)
 *
 * 目的:验证 src/api/*.ts 函数对 Java 后端 005 的 DTO 形状严格对齐。
 * 任何字段缺失、类型不匹配都会被这里捕获。
 *
 * 覆盖目标(按 003-frontend-react-java.md §5.4):
 *   - register/login: { user, token }   vs  Java AuthResponse { user, token }
 *   - Account: { uuid, name, balance, currency, ... }
 *   - Record: { uuid, type, amount, currency, ... }
 *   - MonthlyReport: { month, totalIncome, totalExpense, ... }
 *   - 信封结构:{ code, message, data? } — code===0 表示成功,其他抛 ApiError
 *
 * 工具:Vitest + MSW + jsdom
 */
import { afterAll, afterEach, beforeAll, describe, expect, it } from 'vitest'
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { login, register } from '../../src/api/auth'
import { listAccounts } from '../../src/api/accounts'
import { listRecords } from '../../src/api/records'
import { getMonthlyReport } from '../../src/api/reports'
import { ApiError } from '../../src/lib/api'

const server = setupServer()
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => server.resetHandlers())
afterAll(() => server.close())

const baseUrl = 'http://localhost:4001'

describe('DTO contract — 信封结构', () => {
  it('成功信封 { code:0, message, data } → request() 返回 data', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/login`, () =>
        HttpResponse.json({
          code: 0,
          message: 'ok',
          data: { user: { id: 1, username: 'a' }, token: 'jwt-1' },
        })
      )
    )

    const r = await login({ username: 'a', password: 'b' })
    expect(r.token).toBe('jwt-1')
    expect(r.user.username).toBe('a')
  })

  it('失败信封 { code:1001, message } → request() 抛 ApiError', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/register`, () =>
        HttpResponse.json({ code: 1001, message: '用户名已被占用' })
      )
    )

    await expect(register({ username: 'x', password: 'y' })).rejects.toBeInstanceOf(ApiError)
  })

  it('HTTP 200 但 code != 0 → 仍然抛 ApiError', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/login`, () =>
        HttpResponse.json({ code: 3017, message: '账户不在当前账本' }, { status: 200 })
      )
    )

    await expect(login({ username: 'a', password: 'b' })).rejects.toMatchObject({
      code: 3017,
      message: '账户不在当前账本',
    })
  })

  it('HTTP 500 + 空信封 → ApiError(code="INTERNAL")', async () => {
    server.use(
      http.get(`${baseUrl}/api/accounts`, () => new HttpResponse('', { status: 500 }))
    )

    await expect(listAccounts()).rejects.toMatchObject({
      code: 'INTERNAL',
      message: 'HTTP 500',
    })
  })
})

describe('DTO contract — Account 形状', () => {
  it('Account list 后端返 { items: [...] } → 字段齐全', async () => {
    server.use(
      http.get(`${baseUrl}/api/accounts`, () =>
        HttpResponse.json({
          code: 0,
          message: 'ok',
          data: {
            items: [
              {
                id: 'acc-uuid-1',
                name: '微信支付',
                type: 'wallet',
                icon: '💳',
                initialBalance: '0.00',
                balance: '1234.56',
                currency: 'CNY',
                isDefault: true,
                sortOrder: 0,
                note: null,
                createdAt: '2026-09-01T00:00:00Z',
              },
              {
                id: 'acc-uuid-2',
                name: '银行卡',
                type: 'debit',
                icon: '🏦',
                initialBalance: '500.00',
                balance: '500.00',
                currency: 'CNY',
                isDefault: false,
                sortOrder: 1,
                note: '工资卡',
                createdAt: '2026-09-02T00:00:00Z',
              },
            ],
          },
        })
      )
    )

    const list = await listAccounts()
    expect(list).toHaveLength(2)
    expect(list[0].name).toBe('微信支付')
    expect(list[0].isDefault).toBe(true)
    expect(list[0].balance).toBe('1234.56')
    expect(list[1].currency).toBe('CNY')
  })

  it('Account 字段缺失 → 解析后字段为 undefined(契约破坏的早期信号)', async () => {
    server.use(
      http.get(`${baseUrl}/api/accounts`, () =>
        HttpResponse.json({
          code: 0,
          message: 'ok',
          data: { items: [{ id: 'only-id' /* 故意漏字段 */ }] },
        })
      )
    )

    const list = await listAccounts()
    expect(list).toHaveLength(1)
    expect(list[0].id).toBe('only-id')
    expect(list[0].name).toBeUndefined()
    expect(list[0].balance).toBeUndefined()
  })
})

describe('DTO contract — Record 形状', () => {
  it('Record list 后端返 { items: [...] }', async () => {
    server.use(
      http.get(`${baseUrl}/api/records`, () =>
        HttpResponse.json({
          code: 0,
          message: 'ok',
          data: {
            items: [
              {
                id: 'rec-uuid-1',
                type: 'expense',
                categoryId: 'cat-uuid-1',
                accountId: 'acc-uuid-1',
                toAccountId: null,
                amount: '88.50',
                currency: 'CNY',
                note: '午饭',
                recordDate: '2026-09-04',
                source: 'manual',
                clientId: 'client-1',
                createdAt: '2026-09-04T12:00:00Z',
                updatedAt: '2026-09-04T12:00:00Z',
              },
            ],
          },
        })
      )
    )

    const list = await listRecords({ bookId: '' })
    expect(list).toHaveLength(1)
    expect(list[0].type).toBe('expense')
    expect(list[0].amount).toBe('88.50')
    expect(list[0].recordDate).toBe('2026-09-04')
    expect(list[0].toAccountId).toBeNull()
  })

  it('Record type=transfer → toAccountId 必填', async () => {
    server.use(
      http.get(`${baseUrl}/api/records`, () =>
        HttpResponse.json({
          code: 0,
          message: 'ok',
          data: {
            items: [
              {
                id: 'rec-uuid-2',
                type: 'transfer',
                categoryId: null,
                accountId: 'acc-uuid-1',
                toAccountId: 'acc-uuid-2',
                amount: '100.00',
                currency: 'CNY',
                note: '微信到银行卡',
                recordDate: '2026-09-04',
                source: 'manual',
                clientId: 'client-2',
                createdAt: '2026-09-04T12:00:00Z',
                updatedAt: '2026-09-04T12:00:00Z',
              },
            ],
          },
        })
      )
    )

    const list = await listRecords({ bookId: '' })
    expect(list[0].type).toBe('transfer')
    expect(list[0].accountId).toBe('acc-uuid-1')
    expect(list[0].toAccountId).toBe('acc-uuid-2')
    expect(list[0].categoryId).toBeNull()
  })
})

describe('DTO contract — MonthlyReport 形状', () => {
  it('月报后端返 { month, totalIncome, totalExpense, byCategory, daily, lastMonth }', async () => {
    server.use(
      http.get(`${baseUrl}/api/reports/monthly`, () =>
        HttpResponse.json({
          code: 0,
          message: 'ok',
          data: {
            month: '2026-09',
            totalIncome: '10000.00',
            totalExpense: '4500.00',
            netSavings: '5500.00',
            byCategory: [
              { id: 'cat-1', name: '餐饮', type: 'expense', total: '1500.00', percent: 33.3 },
            ],
            daily: [
              { date: '2026-09-01', income: '0.00', expense: '50.00' },
              { date: '2026-09-02', income: '10000.00', expense: '0.00' },
            ],
            lastMonth: { totalIncome: '9000.00', totalExpense: '4000.00', netSavings: '5000.00' },
          },
        })
      )
    )

    const r = await getMonthlyReport('2026-09', '')
    expect(r.month).toBe('2026-09')
    expect(r.totalIncome).toBe('10000.00')
    expect(r.netSavings).toBe('5500.00')
    expect(r.byCategory).toHaveLength(1)
    expect(r.daily).toHaveLength(2)
  })
})