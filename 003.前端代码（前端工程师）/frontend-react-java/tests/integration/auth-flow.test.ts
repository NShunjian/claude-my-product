// @vitest-environment jsdom
/**
 * 003 frontend-react-java — Auth API 集成测试(MSW + 真实断言)
 *
 * 覆盖目标(按 003-frontend-react-java.md §5.3):
 *   - register → 拿到 user + token
 *   - login → 拿到 user + token
 *   - me → 拿到 User 对象
 *   - 401 全局通知:后端 1401 触发 onAuthInvalid listener
 *   - 业务错误(1001 用户名已占用)抛 ApiError(code=1001)
 *   - 字段错位 → ApiError
 *
 * 工具:Vitest + MSW + jsdom(测试 src/api/*.ts 真实路径)
 */
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { login, logout, me, register } from '../../src/api/auth'
import { ApiError, getToken, onAuthInvalid } from '../../src/lib/api'

const server = setupServer()

beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => {
  server.resetHandlers()
  localStorage.clear()
})
afterAll(() => server.close())

const baseUrl = 'http://localhost:4001'

const mockUser = {
  id: 1,
  uuid: 'user-uuid-001',
  username: 'alice',
  displayName: 'Alice',
  avatar: null,
  gender: null,
  age: null,
  createdAt: '2026-09-01T00:00:00Z',
}

describe('Auth API', () => {
  it('register → 后端返 { user, token } → 直接拿到 user + token', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/register`, async ({ request }) => {
        const body = (await request.json()) as { username: string; password: string }
        expect(body.username).toBe('alice')
        expect(body.password).toBe('Secret@123')
        return HttpResponse.json({ code: 0, message: 'ok', data: { user: mockUser, token: 'jwt-token-abc' } })
      })
    )

    const res = await register({ username: 'alice', password: 'Secret@123' })
    expect(res.user.username).toBe('alice')
    expect(res.user.uuid).toBe('user-uuid-001')
    expect(res.token).toBe('jwt-token-abc')
  })

  it('login → 拿到 user + token', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/login`, async () => {
        return HttpResponse.json({ code: 0, message: 'ok', data: { user: mockUser, token: 'jwt-token-xyz' } })
      })
    )

    const res = await login({ username: 'alice', password: 'Secret@123' })
    expect(res.token).toBe('jwt-token-xyz')
    expect(res.user.id).toBe(1)
  })

  it('me → 带 token → 拿到 User 对象', async () => {
    localStorage.setItem('qz_token', 'bearer-token-1')
    server.use(
      http.get(`${baseUrl}/api/auth/me`, ({ request }) => {
        expect(request.headers.get('Authorization')).toBe('Bearer bearer-token-1')
        return HttpResponse.json({ code: 0, message: 'ok', data: mockUser })
      })
    )

    const u = await me()
    expect(u.username).toBe('alice')
    expect(u.uuid).toBe('user-uuid-001')
  })

  it('业务错误 1001(用户名已占用)→ 抛 ApiError(code=1001)', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/register`, () => {
        return HttpResponse.json({ code: 1001, message: '用户名已被占用' }, { status: 200 })
      })
    )

    await expect(
      register({ username: 'existing', password: 'x' })
    ).rejects.toMatchObject({
      name: 'ApiError',
      code: 1001,
      message: '用户名已被占用',
    })
  })

  it('业务错误 1002(密码错)→ 抛 ApiError(code=1002)', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/login`, () => {
        return HttpResponse.json({ code: 1002, message: '用户名或密码错误' }, { status: 200 })
      })
    )

    await expect(login({ username: 'alice', password: 'wrong' }))
      .rejects.toBeInstanceOf(ApiError)
  })

  it('后端返 1401 → 触发 onAuthInvalid listener', async () => {
    const spy = vi.fn()
    const off = onAuthInvalid(spy)
    server.use(
      http.get(`${baseUrl}/api/auth/me`, () => {
        return HttpResponse.json({ code: 1401, message: '未登录' }, { status: 400 })
      })
    )

    await expect(me()).rejects.toBeInstanceOf(ApiError)
    expect(spy).toHaveBeenCalledTimes(1)
    off()
  })

  it('HTTP 500 无信封 → ApiError,code="INTERNAL",message 带状态码', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/login`, () => {
        return new HttpResponse('oops', { status: 500 })
      })
    )

    await expect(login({ username: 'a', password: 'b' }))
      .rejects.toMatchObject({ code: 'INTERNAL', message: 'HTTP 500' })
  })

  it('token 缺失 → request() 不注入 Authorization header', async () => {
    expect(getToken()).toBeNull()
    let capturedAuth: string | null = 'unset'
    server.use(
      http.get(`${baseUrl}/api/auth/me`, ({ request }) => {
        capturedAuth = request.headers.get('Authorization')
        return HttpResponse.json({ code: 0, message: 'ok', data: mockUser })
      })
    )

    await me()
    expect(capturedAuth).toBeNull()
  })

  it('logout → 200 ok 路径正常', async () => {
    server.use(
      http.post(`${baseUrl}/api/auth/logout`, () => {
        return HttpResponse.json({ code: 0, message: 'ok', data: { ok: true } })
      })
    )

    const r = await logout()
    expect(r.ok).toBe(true)
  })

  it('同一 listener 多次注册 → onAuthInvalid 触发时全部调用', async () => {
    const a = vi.fn()
    const b = vi.fn()
    const offA = onAuthInvalid(a)
    const offB = onAuthInvalid(b)
    server.use(
      http.get(`${baseUrl}/api/auth/me`, () =>
        HttpResponse.json({ code: 1401, message: '未登录' }, { status: 400 })
      )
    )

    await expect(me()).rejects.toBeInstanceOf(ApiError)
    expect(a).toHaveBeenCalledTimes(1)
    expect(b).toHaveBeenCalledTimes(1)
    offA()
    offB()
  })

  it('off() 注销 listener → 后续 1401 不再触发', async () => {
    const spy = vi.fn()
    const off = onAuthInvalid(spy)
    server.use(
      http.get(`${baseUrl}/api/auth/me`, () =>
        HttpResponse.json({ code: 1401, message: '未登录' }, { status: 400 })
      )
    )

    await expect(me()).rejects.toBeInstanceOf(ApiError)
    expect(spy).toHaveBeenCalledTimes(1)

    off()
    server.resetHandlers()
    server.use(
      http.get(`${baseUrl}/api/auth/me`, () =>
        HttpResponse.json({ code: 1401, message: '未登录' }, { status: 400 })
      )
    )
    await expect(me()).rejects.toBeInstanceOf(ApiError)
    expect(spy).toHaveBeenCalledTimes(1) // 没增加
  })
})