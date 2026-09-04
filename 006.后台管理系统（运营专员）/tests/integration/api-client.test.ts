// @vitest-environment jsdom
/**
 * 006 admin-frontend — api/client.ts 集成测试(MSW + 真实断言)
 *
 * 覆盖目标(按 006-admin-frontend.md §4 H6 + §5.1):
 *   - request<T>() 401 → dispatch admin-auth-expired + 清 token + 抛 ApiError
 *   - request<T>() 后端 14xx envelope → 抛 ApiError(code, message)
 *   - request<T>() 解析 envelope {code, message, data} → 返回 data
 *   - GET 自动拼接 query string
 *   - POST/PATCH 自动 JSON.stringify + Content-Type
 *
 * 工具:MSW(拦截 fetch)+ Vitest + jsdom
 */
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { ApiError, clearAuth, getToken, request, setToken } from '../../src/api/client'

const server = setupServer()
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => {
  server.resetHandlers()
  clearAuth()
})
afterAll(() => server.close())

const baseUrl = 'http://localhost:4001'

describe('api/client — 信封与异常', () => {
  it('成功 envelope { code:0, data } → 返回 data', async () => {
    server.use(
      http.get(`${baseUrl}/api/admin/auth/me`, () =>
        HttpResponse.json({ code: 0, message: 'ok', data: { id: 1, username: 'admin' } })
      )
    )

    const r = await request<{ id: number; username: string }>('/api/admin/auth/me')
    expect(r.id).toBe(1)
    expect(r.username).toBe('admin')
  })

  it('失败 envelope { code:1411 } → 抛 ApiError(1411)', async () => {
    server.use(
      http.get(`${baseUrl}/api/admin/users`, () =>
        HttpResponse.json({ code: 1411, message: '权限不足' })
      )
    )

    await expect(request('/api/admin/users')).rejects.toMatchObject({
      name: 'ApiError',
      code: 1411,
      message: '权限不足',
    })
  })

  it('HTTP 401 → 清 token + 派发 admin-auth-expired 事件 + 抛 ApiError(401)', async () => {
    setToken('expired-token')
    const spy = vi.fn()
    window.addEventListener('admin-auth-expired', spy)

    server.use(
      http.get(`${baseUrl}/api/admin/auth/me`, () =>
        new HttpResponse(JSON.stringify({ message: 'token expired' }), { status: 401 })
      )
    )

    await expect(request('/api/admin/auth/me')).rejects.toMatchObject({
      name: 'ApiError',
      code: 401,
      httpStatus: 401,
    })

    expect(getToken()).toBeNull()
    expect(spy).toHaveBeenCalledTimes(1)
    expect(spy.mock.calls[0][0].detail.message).toBe('登录已过期,请重新登录')

    window.removeEventListener('admin-auth-expired', spy)
  })

  it('HTTP 500 非 JSON 响应 → ApiError(code=500)', async () => {
    server.use(
      http.get(`${baseUrl}/api/admin/users`, () =>
        new HttpResponse('<html>500 Internal Server Error</html>', {
          status: 500,
          headers: { 'Content-Type': 'text/html' },
        })
      )
    )

    await expect(request('/api/admin/users')).rejects.toMatchObject({
      code: 500,
      httpStatus: 500,
    })
  })

  it('envelope code=0 但 message 是空串 → 不抛错,正常返 data', async () => {
    server.use(
      http.get(`${baseUrl}/api/admin/auth/me`, () =>
        HttpResponse.json({ code: 0, message: '', data: { id: 1 } })
      )
    )

    const r = await request<{ id: number }>('/api/admin/auth/me')
    expect(r.id).toBe(1)
  })
})

describe('api/client — Request 拼装', () => {
  it('GET 自动拼接 query string(空值跳过)', async () => {
    let capturedUrl = ''
    server.use(
      http.get(`${baseUrl}/api/admin/users`, ({ request }) => {
        capturedUrl = request.url
        return HttpResponse.json({
          code: 0,
          message: 'ok',
          data: { records: [], total: 0, size: 20, current: 1 },
        })
      })
    )

    interface Resp { records: unknown[]; total: number }
    const r = await request<Resp>('/api/admin/users', {
      query: { page: 1, size: 20, status: 1, keyword: '' /* 空串应跳过 */ },
    })
    expect(r.records).toEqual([])
    // 验证 URL 含 page=1,size=20,status=1,且不含 keyword=
    expect(capturedUrl).toContain('page=1')
    expect(capturedUrl).toContain('size=20')
    expect(capturedUrl).toContain('status=1')
    expect(capturedUrl).not.toContain('keyword')
  })

  it('POST 自动 JSON.stringify + Content-Type: application/json', async () => {
    let capturedBody: string | null = null
    let capturedContentType: string | null = null
    server.use(
      http.post(`${baseUrl}/api/admin/auth/login`, async ({ request }) => {
        capturedContentType = request.headers.get('Content-Type')
        capturedBody = await request.text()
        return HttpResponse.json({
          code: 0,
          message: 'ok',
          data: { user: { id: 1, uuid: 'u1', username: 'admin', displayName: 'Admin' }, token: 'jwt-x', permissions: [], roleCodes: [], isSuperAdmin: false },
        })
      })
    )

    await request('/api/admin/auth/login', {
      method: 'POST',
      body: { username: 'admin', password: 'secret' },
    })
    expect(capturedContentType).toBe('application/json')
    expect(JSON.parse(capturedBody!)).toEqual({ username: 'admin', password: 'secret' })
  })

  it('带 token → 自动注入 Authorization: Bearer <token>', async () => {
    setToken('my-jwt-token')
    let capturedAuth: string | null = null
    server.use(
      http.get(`${baseUrl}/api/admin/users`, ({ request }) => {
        capturedAuth = request.headers.get('Authorization')
        return HttpResponse.json({ code: 0, message: 'ok', data: { records: [], total: 0 } })
      })
    )

    await request('/api/admin/users')
    expect(capturedAuth).toBe('Bearer my-jwt-token')
  })

  it('无 token → 不带 Authorization header', async () => {
    let capturedAuth: string | null = 'sentinel'
    server.use(
      http.get(`${baseUrl}/api/admin/users`, ({ request }) => {
        capturedAuth = request.headers.get('Authorization')
        return HttpResponse.json({ code: 0, message: 'ok', data: { records: [], total: 0 } })
      })
    )

    await request('/api/admin/users')
    expect(capturedAuth).toBeNull()
  })
})

describe('api/client — 错误 ApiError 实例', () => {
  it('ApiError 包含 code/message/httpStatus 字段', async () => {
    server.use(
      http.get(`${baseUrl}/api/admin/x`, () =>
        HttpResponse.json({ code: 9999, message: '系统内部错误' })
      )
    )

    try {
      await request('/api/admin/x')
      expect.fail('should have thrown')
    } catch (e) {
      expect(e).toBeInstanceOf(ApiError)
      const err = e as ApiError
      expect(err.code).toBe(9999)
      expect(err.message).toBe('系统内部错误')
      expect(err.httpStatus).toBe(200) // envelope 走 200
      expect(err.name).toBe('ApiError')
    }
  })
})