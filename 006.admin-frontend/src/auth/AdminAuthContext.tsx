import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react'
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
