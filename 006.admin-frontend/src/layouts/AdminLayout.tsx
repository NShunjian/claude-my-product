import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { useAdminAuth } from '../auth/AdminAuthContext'
import { usePermissions } from '../auth/usePermissions'

interface NavItem {
  to: string
  label: string
  /** 至少需要这个权限码才显示;缺省 = 总显示 */
  code?: string
}

const NAV: NavItem[] = [
  { to: '/dashboard', label: 'Dashboard' },
  { to: '/users', label: '管理员账号', code: 'user:list' },
  { to: '/business-users', label: '业务用户', code: 'business_user:list' },
  { to: '/categories', label: '预设分类', code: 'category:preset:list' },
  { to: '/books', label: '账本', code: 'book:list' },
  { to: '/records', label: '流水', code: 'record:list' },
  { to: '/audit-logs', label: '审计日志', code: 'audit:list' },
]

export function AdminLayout() {
  const { user, logout, isSuperAdmin } = useAdminAuth()
  const { has } = usePermissions()
  const navigate = useNavigate()

  function onLogout() {
    logout()
    navigate('/login', { replace: true })
  }

  const items = NAV.filter((n) => !n.code || has(n.code))

  return (
    <div className="min-h-screen flex bg-bg-page">
      <aside className="w-56 bg-bg-card border-r border-divider p-4 flex flex-col">
        <div className="text-lg font-bold text-primary mb-6">QingZhang Admin</div>
        <nav className="flex flex-col gap-1 flex-1">
          {items.map((n) => (
            <NavLink
              key={n.to}
              to={n.to}
              className={({ isActive }) =>
                'px-3 py-2 rounded-lg text-sm transition-colors ' +
                (isActive
                  ? 'bg-primary-light text-primary-container font-medium'
                  : 'text-on-surface-variant hover:bg-surface')
              }
            >
              {n.label}
            </NavLink>
          ))}
        </nav>
      </aside>

      <div className="flex-1 flex flex-col">
        <header className="h-14 bg-bg-card border-b border-divider px-6 flex items-center justify-end gap-4">
          <span className="text-sm text-on-surface-variant">
            {user?.displayName ?? user?.username}
            {isSuperAdmin && (
              <span className="ml-2 px-1.5 py-0.5 rounded bg-warning text-white text-xs">SUPER</span>
            )}
          </span>
          <button
            onClick={onLogout}
            className="text-sm text-on-surface-variant hover:text-error transition-colors"
          >
            登出
          </button>
        </header>
        <main className="flex-1 overflow-auto">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
