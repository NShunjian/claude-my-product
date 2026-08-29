import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import * as authApi from '../api/auth'
import type { Credentials, User } from '../api/auth'
import { ApiError, onAuthInvalid } from '../lib/api'
import { useToast } from '../components/Toast'

const TOKEN_KEY = 'qz_token'

export interface AuthContextValue {
  token: string | null
  user: User | null
  loading: boolean
  login: (input: Credentials) => Promise<void>
  register: (input: Credentials) => Promise<void>
  logout: () => Promise<void>
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
    // AbortController:StrictMode dev 下双跑 / 组件卸载时取消未完成请求,避免 setState 已 unmount 组件
    const controller = new AbortController()
    authApi
      .me({ signal: controller.signal })
      .then((user) => {
        setUser(user)
      })
      .catch((err: unknown) => {
        // 主动 abort 不当作错误(组件卸载或 StrictMode 重跑)
        if (err instanceof DOMException && err.name === 'AbortError') return
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
    return () => controller.abort()
  }, [])

  // 全局 401 监听:任何 request() 遇 401(token 失效) → 清状态,ProtectedRoute 自动跳登录
  useEffect(() => {
    const off = onAuthInvalid(() => {
      localStorage.removeItem(TOKEN_KEY)
      setToken(null)
      setUser(null)
    })
    return off
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

  const logout = useCallback(async (): Promise<void> => {
    // 先通知后端(JWT 无状态,后端不维护黑名单,但保留调用为未来扩展 / 当前审计)
    try {
      await authApi.logout()
    } catch (err) {
      // 后端 logout 失败不阻断前端清 token
      console.warn('[logout] 后端 logout 接口失败', err)
    }
    localStorage.removeItem(TOKEN_KEY)
    setToken(null)
    setUser(null)
  }, [])

  const refreshUser = useCallback(async (): Promise<void> => {
    try {
      const user = await authApi.me()
      setUser(user)
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