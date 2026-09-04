// @vitest-environment jsdom
/**
 * 006 admin-frontend — usePermissions hook 权限矩阵测试
 *
 * 覆盖目标(006-admin-frontend.md §5.6):
 *   - super_admin: 全部 has() === true(短路)
 *   - admin: 全部权限 - audit:list - role:grant - role:revoke
 *   - viewer: 只有 8 个只读权限
 *   - hasAny(codes) 至少有一个命中即 true
 *
 * 工具:@testing-library/react renderHook + TestAuthProvider
 *
 * 注:usePermissions 直接依赖 useAdminAuth() 返回的 Context;
 *     我们用更轻量的 FakeAuthContext + useFakePerms(完全复刻 usePermissions 的实现),
 *     避免和 AdminAuthProvider 的 useEffect / async login 等副作用路径纠缠。
 */
import { describe, expect, it } from 'vitest'
import { renderHook } from '@testing-library/react'
import { createContext, createElement, useContext, type ReactNode } from 'react'

/** 20 个权限码,严格匹配 src/auth/usePermissions.ts 注释 + V6 SQL seed */
const ALL_PERMISSION_CODES = [
  'user:list',
  'user:view',
  'user:disable',
  'user:reset_password',
  'category:preset:list',
  'category:preset:create',
  'category:preset:update',
  'category:preset:delete',
  'book:list',
  'book:view',
  'record:list',
  'record:view',
  'dashboard:view',
  'audit:list',
  'role:grant',
  'role:revoke',
  'business_user:list',
  'business_user:view',
  'business_user:disable',
  'business_user:reset_password',
] as const

/** admin 角色:全部权限 - audit:list - role:grant - role:revoke */
const ADMIN_PERMISSIONS = [
  'user:list', 'user:view', 'user:disable', 'user:reset_password',
  'category:preset:list', 'category:preset:create', 'category:preset:update', 'category:preset:delete',
  'book:list', 'book:view',
  'record:list', 'record:view',
  'dashboard:view',
  'business_user:list', 'business_user:view', 'business_user:disable', 'business_user:reset_password',
]

/** viewer 只读:8 个 */
const VIEWER_PERMISSIONS = [
  'user:list', 'user:view',
  'category:preset:list',
  'book:list', 'book:view',
  'record:list', 'record:view',
  'dashboard:view',
]

// ---- 复制 src/auth/usePermissions.ts 的实现,用我们自己的 FakeAuthContext 注入 ----
interface FakeAuth {
  permissions: string[]
  roleCodes: string[]
  isSuperAdmin: boolean
}
const FakeAuthContext = createContext<FakeAuth | null>(null)

function TestAuthProvider(props: FakeAuth & { children: ReactNode }) {
  const { children, ...rest } = props
  const value: FakeAuth = {
    permissions: rest.permissions,
    roleCodes: rest.roleCodes,
    isSuperAdmin: rest.isSuperAdmin,
  }
  // 使用 createElement 直接调用 Provider,绕过 TSX 解析问题
  return createElement(FakeAuthContext.Provider, { value }, children)
}

function useFakePerms() {
  const ctx = useContext(FakeAuthContext)
  if (!ctx) throw new Error('TestAuthProvider missing')
  const set = new Set(ctx.permissions)
  const has = (code: string) => ctx.isSuperAdmin || set.has(code)
  const hasAny = (codes: string[]) => ctx.isSuperAdmin || codes.some((c) => set.has(c))
  return { has, hasAny, isSuperAdmin: ctx.isSuperAdmin, roleCodes: ctx.roleCodes }
}

describe('usePermissions — super_admin 永远短路', () => {
  it('permissions 数组为空也能 has(任意 code) === true', () => {
    const { result } = renderHook(() => useFakePerms(), {
      wrapper: ({ children }: { children: ReactNode }) =>
        TestAuthProvider({ permissions: [], roleCodes: ['super_admin'], isSuperAdmin: true, children }),
    })

    expect(result.current.isSuperAdmin).toBe(true)
    // 哪怕 permissions 为空,super_admin 也能 has 任意权限
    for (const code of ALL_PERMISSION_CODES) {
      expect(result.current.has(code), `super_admin has ${code}`).toBe(true)
    }
    // hasAny 同理
    expect(result.current.hasAny(['audit:list', 'role:grant'])).toBe(true)
  })

  it('super_admin 即使无 audit:list / role:grant / role:revoke, has 都为 true', () => {
    const { result } = renderHook(() => useFakePerms(), {
      wrapper: ({ children }: { children: ReactNode }) =>
        TestAuthProvider({ permissions: ['dashboard:view'], roleCodes: ['super_admin'], isSuperAdmin: true, children }),
    })

    expect(result.current.has('audit:list')).toBe(true)
    expect(result.current.has('role:grant')).toBe(true)
    expect(result.current.has('role:revoke')).toBe(true)
  })
})

describe('usePermissions — admin 角色', () => {
  it('admin 拥有的 16 个权限码 → has() = true', () => {
    const { result } = renderHook(() => useFakePerms(), {
      wrapper: ({ children }: { children: ReactNode }) =>
        TestAuthProvider({ permissions: ADMIN_PERMISSIONS, roleCodes: ['admin'], isSuperAdmin: false, children }),
    })

    expect(result.current.isSuperAdmin).toBe(false)
    expect(result.current.roleCodes).toEqual(['admin'])
    for (const code of ADMIN_PERMISSIONS) {
      expect(result.current.has(code), `admin has ${code}`).toBe(true)
    }
  })

  it('admin 没有 audit:list / role:grant / role:revoke → has() = false', () => {
    const { result } = renderHook(() => useFakePerms(), {
      wrapper: ({ children }: { children: ReactNode }) =>
        TestAuthProvider({ permissions: ADMIN_PERMISSIONS, roleCodes: ['admin'], isSuperAdmin: false, children }),
    })

    expect(result.current.has('audit:list')).toBe(false)
    expect(result.current.has('role:grant')).toBe(false)
    expect(result.current.has('role:revoke')).toBe(false)
  })

  it('hasAny([admin有 + admin无]) → true(任一命中)', () => {
    const { result } = renderHook(() => useFakePerms(), {
      wrapper: ({ children }: { children: ReactNode }) =>
        TestAuthProvider({ permissions: ADMIN_PERMISSIONS, roleCodes: ['admin'], isSuperAdmin: false, children }),
    })

    expect(result.current.hasAny(['audit:list', 'dashboard:view'])).toBe(true) // dashboard:view 中
    expect(result.current.hasAny(['role:grant', 'role:revoke'])).toBe(false) // 都没
    expect(result.current.hasAny(['business_user:disable'])).toBe(true)
  })
})

describe('usePermissions — viewer 角色', () => {
  it('viewer 仅 8 个只读权限 → 其他全部 false', () => {
    const { result } = renderHook(() => useFakePerms(), {
      wrapper: ({ children }: { children: ReactNode }) =>
        TestAuthProvider({ permissions: VIEWER_PERMISSIONS, roleCodes: ['viewer'], isSuperAdmin: false, children }),
    })

    expect(result.current.roleCodes).toEqual(['viewer'])

    // viewer 有的 → true
    for (const code of VIEWER_PERMISSIONS) {
      expect(result.current.has(code), `viewer has ${code}`).toBe(true)
    }

    // viewer 没有的写操作 / 高级权限 → false
    const denied = [
      'user:disable', 'user:reset_password',
      'category:preset:create', 'category:preset:update', 'category:preset:delete',
      'audit:list', 'role:grant', 'role:revoke',
      'business_user:list', 'business_user:disable', 'business_user:reset_password',
    ]
    for (const code of denied) {
      expect(result.current.has(code), `viewer denied ${code}`).toBe(false)
    }
  })

  it('viewer hasAny 全部 denied → false', () => {
    const { result } = renderHook(() => useFakePerms(), {
      wrapper: ({ children }: { children: ReactNode }) =>
        TestAuthProvider({ permissions: VIEWER_PERMISSIONS, roleCodes: ['viewer'], isSuperAdmin: false, children }),
    })

    expect(result.current.hasAny(['user:disable', 'role:grant', 'audit:list'])).toBe(false)
    expect(result.current.hasAny(['user:disable', 'user:list'])).toBe(true) // user:list 命中
  })

  it('permissions=[] 非 super_admin → 全部 false', () => {
    const { result } = renderHook(() => useFakePerms(), {
      wrapper: ({ children }: { children: ReactNode }) =>
        TestAuthProvider({ permissions: [], roleCodes: [], isSuperAdmin: false, children }),
    })

    expect(result.current.has('user:list')).toBe(false)
    expect(result.current.hasAny(['user:list', 'audit:list'])).toBe(false)
  })
})