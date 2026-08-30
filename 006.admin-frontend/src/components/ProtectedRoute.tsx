import { Navigate, useLocation } from 'react-router-dom'
import { useAdminAuth } from '../auth/AdminAuthContext'
import type { ReactNode } from 'react'

/**
 * 路由守卫 —— 已登录渲染 children,未登录跳 /login 并保留原地址用于登录后回跳。
 *
 * isLoading 时显示 loading 占位,避免初次 mount 时把已登录用户错误地跳走。
 */
export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { isAuthenticated, isLoading } = useAdminAuth()
  const location = useLocation()
  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center text-on-surface-variant">
        正在校验登录态…
      </div>
    )
  }
  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }
  return <>{children}</>
}
