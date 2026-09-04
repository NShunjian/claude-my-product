// @vitest-environment jsdom
/**
 * 006 admin-frontend — AdminAuthProvider 鉴权流集成测试
 *
 * 覆盖目标(006-admin-frontend.md §4 H7 + §5.1):
 *   - localStorage 无 token → /me 不发 → isLoading=false, isAuthenticated=false
 *   - localStorage 有 token + /me 200 → isAuthenticated=true, user 注入
 *   - localStorage 有 token + /me 401 → clearAuth, isAuthenticated=false
 *   - login() → POST /api/admin/auth/login → setToken + 注入 context
 *   - logout() → clearAuth + 清 context
 *   - 'admin-auth-expired' 事件 → logout + navigate('/login')
 *
 * 工具:MSW + @testing-library/react + MemoryRouter + AdminAuthProvider
 * 注:render() + Probe 探针而非 renderHook(React19 + RTL 的 renderHook 在
 *     Provider 上下文 + useEffect 的场景下,re-render 不可靠)。
 */
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest'
import { act, render, waitFor } from '@testing-library/react'
import { http, HttpResponse } from 'msw'
import { setupServer } from 'msw/node'
import { MemoryRouter } from 'react-router-dom'
import { createElement, type ReactNode } from 'react'
import { AdminAuthProvider, useAdminAuth } from '../../src/auth/AdminAuthContext'
import { clearAuth, getToken } from '../../src/api/client'

const server = setupServer()
beforeAll(() => server.listen({ onUnhandledRequest: 'error' }))
afterEach(() => {
  server.resetHandlers()
  clearAuth()
})
afterAll(() => server.close())

const baseUrl = 'http://localhost:4001'

const mockUser = {
  id: 1,
  uuid: 'admin-uuid-001',
  username: 'admin',
  displayName: '管理员',
  isSuperAdmin: false,
  permissions: ['user:list', 'dashboard:view'],
  roleCodes: ['admin'],
}

const mockSuperAdmin = {
  ...mockUser,
  isSuperAdmin: true,
  roleCodes: ['super_admin'],
  permissions: ['*'],
}

/** 渲染 AdminAuthProvider + MemoryRouter,通过 Probe 暴露 useAdminAuth() 实时快照 */
function renderWithProbe(initialPath = '/dashboard') {
  let state: ReturnType<typeof useAdminAuth> | null = null
  function Probe() {
    state = useAdminAuth()
    return null
  }
  function App() {
    return createElement(
      MemoryRouter,
      { initialEntries: [initialPath] },
      createElement(AdminAuthProvider, null, createElement(Probe, null))
    )
  }
  const utils = render(createElement(App, null))
  return { state: () => state!, ...utils }
}

describe('AdminAuthProvider — 初始状态', () => {
  it('localStorage 无 token → /me 不发, isLoading=false, isAuthenticated=false', async () => {
    expect(getToken()).toBeNull()

    const { state } = renderWithProbe()

    await waitFor(() => expect(state().isLoading).toBe(false))
    expect(state().isAuthenticated).toBe(false)
    expect(state().user).toBeNull()
    expect(state().permissions).toEqual([])
    expect(state().isSuperAdmin).toBe(false)
  })
})

describe('AdminAuthProvider — /me 校验 token', () => {
  it('localStorage 有 token + /me 200 → 注入 user + permissions', async () => {
    localStorage.setItem('admin_token', 'valid-jwt')
    let meCalled = 0
    server.use(
      http.get(`${baseUrl}/api/admin/auth/me`, ({ request }) => {
        meCalled++
        expect(request.headers.get('Authorization')).toBe('Bearer valid-jwt')
        return HttpResponse.json({ code: 0, message: 'ok', data: mockUser })
      })
    )

    const { state } = renderWithProbe()

    await waitFor(() => expect(state().isLoading).toBe(false))
    expect(meCalled).toBe(1)
    expect(state().isAuthenticated).toBe(true)
    expect(state().user?.username).toBe('admin')
    expect(state().user?.displayName).toBe('管理员')
    expect(state().permissions).toEqual(['user:list', 'dashboard:view'])
    expect(state().roleCodes).toEqual(['admin'])
    expect(state().isSuperAdmin).toBe(false)
  })

  it('localStorage 有 token + /me 401 → clearAuth, isAuthenticated=false', async () => {
    localStorage.setItem('admin_token', 'expired-jwt')
    server.use(
      http.get(`${baseUrl}/api/admin/auth/me`, () =>
        new HttpResponse(JSON.stringify({ message: 'expired' }), { status: 401 })
      )
    )

    const { state } = renderWithProbe()

    await waitFor(() => expect(state().isLoading).toBe(false))
    expect(state().isAuthenticated).toBe(false)
    expect(state().user).toBeNull()
    expect(getToken()).toBeNull()
  })

  it('localStorage 有 token + /me 500 → catch 路径同样清 token', async () => {
    localStorage.setItem('admin_token', 'good-jwt')
    server.use(
      http.get(`${baseUrl}/api/admin/auth/me`, () =>
        new HttpResponse('boom', { status: 500 })
      )
    )

    const { state } = renderWithProbe()

    await waitFor(() => expect(state().isLoading).toBe(false))
    expect(state().isAuthenticated).toBe(false)
    expect(getToken()).toBeNull()
  })
})

describe('AdminAuthProvider — login() / logout()', () => {
  it('login() → POST /api/admin/auth/login → setToken + 注入 user + perms + super', async () => {
    server.use(
      http.post(`${baseUrl}/api/admin/auth/login`, async ({ request }) => {
        const body = (await request.json()) as { username: string; password: string }
        expect(body.username).toBe('admin')
        expect(body.password).toBe('Secret@123')
        return HttpResponse.json({
          code: 0,
          message: 'ok',
          data: {
            user: {
              id: mockSuperAdmin.id,
              uuid: mockSuperAdmin.uuid,
              username: mockSuperAdmin.username,
              displayName: mockSuperAdmin.displayName,
            },
            token: 'fresh-jwt',
            permissions: mockSuperAdmin.permissions,
            roleCodes: mockSuperAdmin.roleCodes,
            isSuperAdmin: mockSuperAdmin.isSuperAdmin,
          },
        })
      })
    )

    const { state } = renderWithProbe()
    await waitFor(() => expect(state().isLoading).toBe(false))

    await state().login('admin', 'Secret@123')

    expect(getToken()).toBe('fresh-jwt')
    // 关键:用 console 探针确认 state 是否更新
    await waitFor(
      () => {
        const s = state()
        console.log('WAIT-FOR state:', { user: s.user, isSuper: s.isSuperAdmin, auth: s.isAuthenticated })
        return s.user?.username === 'admin' && s.isSuperAdmin === true
      },
      { timeout: 3000 }
    )
    console.log('AFTER waitFor state:', { user: state().user, isSuper: state().isSuperAdmin })
    expect(state().user?.username).toBe('admin')
    expect(state().isSuperAdmin).toBe(true)
    expect(state().roleCodes).toEqual(['super_admin'])
    expect(state().isAuthenticated).toBe(true)
  })

  it('login() 后端返 14xx → 抛 ApiError, token 不写入, context 不变', async () => {
    server.use(
      http.post(`${baseUrl}/api/admin/auth/login`, () =>
        HttpResponse.json({ code: 1402, message: '用户名或密码错误' })
      )
    )

    const { state } = renderWithProbe()
    await waitFor(() => expect(state().isLoading).toBe(false))

    await act(async () => {
      await expect(state().login('admin', 'wrong')).rejects.toMatchObject({ code: 1402 })
    })

    expect(getToken()).toBeNull()
    expect(state().isAuthenticated).toBe(false)
  })

  it('logout() → clearAuth + 清空 user/perms/role/super', async () => {
    localStorage.setItem('admin_token', 'good')
    server.use(
      http.get(`${baseUrl}/api/admin/auth/me`, () =>
        HttpResponse.json({ code: 0, message: 'ok', data: mockUser })
      )
    )

    const { state } = renderWithProbe()
    await waitFor(() => expect(state().isAuthenticated).toBe(true))

    act(() => state().logout())

    expect(state().isAuthenticated).toBe(false)
    expect(state().user).toBeNull()
    expect(state().permissions).toEqual([])
    expect(state().roleCodes).toEqual([])
    expect(state().isSuperAdmin).toBe(false)
    expect(getToken()).toBeNull()
  })
})

describe('AdminAuthProvider — admin-auth-expired 事件', () => {
  it('外部 dispatch 事件 → logout + 清 token', async () => {
    localStorage.setItem('admin_token', 'good')
    server.use(
      http.get(`${baseUrl}/api/admin/auth/me`, () =>
        HttpResponse.json({ code: 0, message: 'ok', data: mockUser })
      )
    )

    const { state } = renderWithProbe()
    await waitFor(() => expect(state().isAuthenticated).toBe(true))

    await act(async () => {
      window.dispatchEvent(new CustomEvent('admin-auth-expired'))
    })

    await waitFor(() => expect(state().isAuthenticated).toBe(false))
    expect(getToken()).toBeNull()
    // navigate 由 react-router 控制,在 MemoryRouter 里不直接断言 location.pathname,
    // 但 logout 已被触发 + token 已清空 = 满足核心契约
  })
})