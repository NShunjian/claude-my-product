import { NavLink, useNavigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { useLanguage } from '../i18n/LanguageContext'

interface NavItem {
  labelKey: string
  icon: string
  to: string
  endsWith?: boolean
}

const NAV_ITEMS: NavItem[] = [
  { labelKey: 'sidebar.home', icon: 'dashboard', to: '/' },
  { labelKey: 'sidebar.reports', icon: 'bar_chart', to: '/reports/monthly' },
  { labelKey: 'sidebar.accounts', icon: 'account_balance_wallet', to: '/accounts' },
  { labelKey: 'sidebar.settings', icon: 'settings', to: '/settings' },
]

export function Sidebar() {
  const navigate = useNavigate()
  const { logout } = useAuth()
  const { t } = useLanguage()

  function handleLogout(): void {
    void logout()  // fire-and-forget:调后端 /api/auth/logout + 清本地 token
    navigate('/login', { replace: true })
  }

  return (
    <nav
      aria-label="Sidebar Navigation"
      className="h-screen w-64 fixed left-0 top-0 bg-surface border-r border-divider flex flex-col p-4 z-40"
    >
      {/* Brand */}
      <div className="mb-8 px-4 mt-2 flex items-center gap-2">
        <span
          className="material-symbols-outlined text-primary"
          style={{ fontSize: '32px', fontVariationSettings: "'FILL' 1" }}
        >
          account_balance
        </span>
        <div>
          <h1 className="font-display-lg text-display-lg font-bold text-primary leading-none">
            轻账
          </h1>
          <p className="font-caption-sm text-caption-sm text-on-surface-variant mt-1">
            {t('sidebar.brandTagline')}
          </p>
        </div>
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
                    ? 'bg-primary-light text-primary font-extrabold border border-primary-light'
                    : 'text-on-surface-variant'
                }`
              }
            >
              {({ isActive }) => (
                <>
                  <span
                    className="material-symbols-outlined"
                    style={{ fontSize: '24px', fontWeight: isActive ? 700 : 400 }}
                  >
                    {item.icon}
                  </span>
                  <span
                    className="font-body-md text-body-md"
                    style={{ fontWeight: isActive ? 800 : 400 }}
                  >
                    {t(item.labelKey)}
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
          {t('sidebar.quickAdd')}
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
        <span className="font-body-md text-body-md">{t('sidebar.logout')}</span>
      </button>
    </nav>
  )
}
