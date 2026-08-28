import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import * as authApi from '../api/auth'
import type { Credentials, User } from '../api/auth'
import { ApiError } from '../lib/api'
import { useToast } from '../components/Toast'

const TOKEN_KEY = 'qz_token'

export interface AuthContextValue {
  token: string | null
  user: User | null
  loading: boolean
  login: (input: Credentials) => Promise<void>
  register: (input: Credentials) => Promise<void>
  logout: () => void
  /** 重新拉一次 me()，多用于资料修改后同步当前用户缓存 */
  refreshUser: () => Promise<void>
  /** 直接覆盖当前 user 缓存，多用于本地乐观更新（如头像预览） */
  setUser: (user: User | null) => void
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(null)
  const [user, setUser] = useState<User | null>(null)
  const [loading, setLoading] = useState<boolean>(true)
  const toast = useToast()

  useEffect(() => {
    const saved = localStorage.getItem(TOKEN_KEY)
    if (!saved) {
      setLoading(false)
      return
    }
    setToken(saved)
    authApi
      .me()
      .then((res) => {
        setUser(res.user)
      })
      .catch((err: unknown) => {
        if (err instanceof ApiError && err.status === 401) {
          localStorage.removeItem(TOKEN_KEY)
          setToken(null)
          setUser(null)
        } else {
          // 网络失败或后端 5xx：提示用户（401 会被 ProtectedRoute 重定向到登录页，由登录页自己处理）
          toast.show('服务暂不可用')
        }
      })
      .finally(() => {
        setLoading(false)
      })
  }, [])

  const login = useCallback(async (input: Credentials): Promise<void> => {
    const res = await authApi.login(input)
    localStorage.setItem(TOKEN_KEY, res.token)
    setToken(res.token)
    setUser(res.user)
  }, [])

  const register = useCallback(async (input: Credentials): Promise<void> => {
    const res = await authApi.register(input)
    localStorage.setItem(TOKEN_KEY, res.token)
    setToken(res.token)
    setUser(res.user)
  }, [])

  const logout = useCallback((): void => {
    localStorage.removeItem(TOKEN_KEY)
    setToken(null)
    setUser(null)
  }, [])

  const refreshUser = useCallback(async (): Promise<void> => {
    try {
      const res = await authApi.me()
      setUser(res.user)
    } catch (err) {
      if (err instanceof ApiError && err.status === 401) {
        localStorage.removeItem(TOKEN_KEY)
        setToken(null)
        setUser(null)
      }
      throw err
    }
  }, [])

  const value = useMemo<AuthContextValue>(
    () => ({ token, user, loading, login, register, logout, refreshUser, setUser }),
    [token, user, loading, login, register, logout, refreshUser],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext)
  if (!ctx) {
    throw new Error('useAuth must be used within an AuthProvider')
  }
  return ctx
}