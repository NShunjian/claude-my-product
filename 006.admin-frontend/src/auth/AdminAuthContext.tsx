import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
import { useNavigate } from 'react-router-dom'
import { clearAuth, getToken, request, setToken } from '../api/client'
import type { AdminMeResponse, AuthLoginResponse, AuthUserDto } from '../api/types'

interface AuthState {
  user: AuthUserDto | null
  permissions: string[]
  roleCodes: string[]
  isSuperAdmin: boolean
  isAuthenticated: boolean
  isLoading: boolean   // true during initial /me validation on mount
  login: (username: string, password: string) => Promise<void>
  logout: () => void
}

const AdminAuthContext = createContext<AuthState | null>(null)

export function AdminAuthProvider({ children }: { children: ReactNode }) {
  const navigate = useNavigate()
  const [user, setUser] = useState<AuthUserDto | null>(null)
  const [permissions, setPermissions] = useState<string[]>([])
  const [roleCodes, setRoleCodes] = useState<string[]>([])
  const [isSuperAdmin, setIsSuperAdmin] = useState(false)
  const [isLoading, setIsLoading] = useState(true)   // start true — /me validation pending

  // On mount: if token exists, validate via /me
  useEffect(() => {
    const token = getToken()
    if (!token) {
      setIsLoading(false)
      return
    }
    request<AdminMeResponse>('/api/admin/auth/me')
      .then((me) => {
        setUser({ id: me.id, uuid: me.uuid, username: me.username, displayName: me.displayName })
        setPermissions(me.permissions)
        setRoleCodes(me.roleCodes)
        setIsSuperAdmin(me.isSuperAdmin)
      })
      .catch(() => {
        clearAuth()
        setUser(null); setPermissions([]); setRoleCodes([]); setIsSuperAdmin(false)
      })
      .finally(() => setIsLoading(false))
  }, [])

  const login = useCallback(async (username: string, password: string) => {
    const res = await request<AuthLoginResponse>('/api/admin/auth/login', {
      method: 'POST',
      body: { username, password },
    })
    setToken(res.token)
    setUser(res.user)
    setPermissions(res.permissions)
    setRoleCodes(res.roleCodes)
    setIsSuperAdmin(res.isSuperAdmin)
  }, [])

  const logout = useCallback(() => {
    clearAuth()
    setUser(null); setPermissions([]); setRoleCodes([]); setIsSuperAdmin(false)
  }, [])

  // 监听 api/client.ts 派发的 'admin-auth-expired' 事件 —— 服务端 token 被作废
  // (V12 token_version 不匹配 / 账号禁用 / 角色没了) 时自动清 context + 跳登录。
  // 不重复 navigate:已登录页时跳一次就行。
  useEffect(() => {
    function onExpired() {
      logout()
      navigate('/login', { replace: true })
    }
    window.addEventListener('admin-auth-expired', onExpired)
    return () => window.removeEventListener('admin-auth-expired', onExpired)
  }, [logout, navigate])

  return (
    <AdminAuthContext.Provider
      value={{
        user, permissions, roleCodes, isSuperAdmin,
        isAuthenticated: !!user,
        isLoading,
        login, logout,
      }}
    >
      {children}
    </AdminAuthContext.Provider>
  )
}

export function useAdminAuth(): AuthState {
  const ctx = useContext(AdminAuthContext)
  if (!ctx) throw new Error('useAdminAuth must be inside AdminAuthProvider')
  return ctx
}
