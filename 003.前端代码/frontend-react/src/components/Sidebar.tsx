import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

interface NavItem {
  label: string
  icon: string
  to: string
  endsWith?: boolean
}

const NAV_ITEMS: NavItem[] = [
  { label: '首页', icon: 'dashboard', to: '/' },
  { label: '报表', icon: 'bar_chart', to: '/reports/monthly' },
  { label: '账户', icon: 'account_balance_wallet', to: '/accounts' },
  { label: '设置', icon: 'settings', to: '/settings' },
]

export function Sidebar() {
  const navigate = useNavigate()
  const { logout } = useAuth()

  function handleLogout(): void {
    logout()
    navigate('/login', { replace: true })
  }

  return (
    <nav
      aria-label="Sidebar Navigation"
      className="h-screen w-64 fixed left-0 top-0 bg-surface border-r border-divider flex flex-col p-4 z-40"
    >
      {/* Brand */}
      <div className="mb-8 px-4 mt-2">
        <h1 className="font-display-lg text-display-lg font-bold text-primary leading-none">
          轻账
        </h1>
        <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-1">
          让财务更清晰
        </p>
      </div>

      {/* Nav Items */}
      <ul className="flex flex-col gap-2 flex-1">
        {NAV_ITEMS.map((item) => (
          <li key={item.to}>
            <NavLink
              to={item.to}
              end={item.endsWith}
              className={({ isActive }) =>
                `px-4 py-3 flex items-center gap-3 rounded-lg transition-colors hover:bg-surface-container ${
                  isActive
                    ? 'bg-primary-light text-primary font-bold'
                    : 'text-on-surface-variant'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <span
                    className="material-symbols-outlined"
                    style={{ fontSize: '24px' }}
                  >
                    {item.icon}
                  </span>
                  <span className="font-body-md text-body-md">
                    {item.label}
                  </span>
                </>
              )}
            </NavLink>
          </li>
        ))}
      </ul>

      {/* CTA */}
      <div className="mt-auto mb-4">
        <NavLink
          to="/record/expense"
          className="w-full bg-primary text-on-primary font-headline-md text-headline-md py-3 rounded-lg hover:bg-primary-container transition-colors flex items-center justify-center gap-2"
        >
          <span
            className="material-symbols-outlined"
            style={{ fontSize: '24px' }}
          >
            add
          </span>
          快速记账
        </NavLink>
      </div>

      {/* Logout */}
      <button
        type="button"
        onClick={handleLogout}
        className="text-on-surface-variant px-4 py-3 flex items-center gap-3 hover:bg-surface-container transition-colors rounded-lg w-full text-left"
      >
        <span className="material-symbols-outlined" style={{ fontSize: '24px' }}>
          logout
        </span>
        <span className="font-body-md text-body-md">退出登录</span>
      </button>
    </nav>
  )
}
