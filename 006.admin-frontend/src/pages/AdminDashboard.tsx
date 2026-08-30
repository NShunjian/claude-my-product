import { useAdminAuth } from '../auth/AdminAuthContext'

/**
 * Dashboard 占位 —— B3 替换为 KPI 卡片 + 7-day 趋势图。
 */
export function AdminDashboard() {
  const { user, isSuperAdmin, roleCodes } = useAdminAuth()
  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-2">Dashboard</h1>
      <p className="text-on-surface-variant mb-4">
        欢迎, {user?.displayName ?? user?.username} ({user?.username})
      </p>
      <div className="rounded-lg border border-divider p-4 bg-bg-card inline-block">
        <div className="text-sm text-on-surface-variant mb-1">角色</div>
        <div className="flex flex-wrap gap-2">
          {roleCodes.map((c) => (
            <span key={c} className="px-2 py-1 rounded bg-primary-light text-primary-container text-sm">
              {c}
            </span>
          ))}
          {isSuperAdmin && (
            <span className="px-2 py-1 rounded bg-warning text-white text-sm">SUPER</span>
          )}
        </div>
      </div>
    </div>
  )
}
