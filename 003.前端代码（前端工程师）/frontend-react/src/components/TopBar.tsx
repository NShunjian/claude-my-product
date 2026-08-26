import { useContext } from 'react'
import { PageTitleContext } from './PageTitleContext'

interface TopBarProps {
  backTo?: string
  backLabel?: string
}

export function TopBar({ backTo, backLabel }: TopBarProps) {
  const { title } = useContext(PageTitleContext)

  return (
    <header className="bg-page sticky top-0 z-30 flex justify-between items-center h-16 px-8 max-w-full border-b border-divider">
      <div className="flex items-center gap-4">
        {backTo && (
          <a
            href={backTo}
            className="text-on-surface-variant hover:text-primary transition-colors flex items-center gap-1 p-1 rounded-full hover:bg-surface-container"
          >
            <span className="material-symbols-outlined text-2xl">arrow_back</span>
            {backLabel && (
              <span className="font-body-md text-body-md ml-1 text-on-surface-variant">
                {backLabel}
              </span>
            )}
          </a>
        )}
        <h2 className="font-headline-md text-headline-md text-primary font-bold">{title}</h2>
      </div>

      <div className="flex items-center gap-4">
        {/* Search */}
        <div className="relative hidden md:block">
          <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-xl">
            search
          </span>
          <input
            className="pl-10 pr-4 py-2 bg-surface-container-lowest border border-divider rounded-full font-body-md text-body-md focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary w-64 transition-colors text-text-primary placeholder-outline"
            placeholder="搜索..."
            type="text"
          />
        </div>

        {/* Notifications */}
        <button
          type="button"
          className="text-on-surface-variant hover:text-primary transition-colors opacity-80 hover:opacity-100"
        >
          <span className="material-symbols-outlined text-xl">notifications</span>
        </button>

        {/* Help */}
        <button
          type="button"
          className="text-on-surface-variant hover:text-primary transition-colors opacity-80 hover:opacity-100"
        >
          <span className="material-symbols-outlined text-xl">help</span>
        </button>

        {/* Support text */}
        <button
          type="button"
          className="font-body-md text-body-md text-on-surface-variant hover:text-primary transition-colors hidden sm:block"
        >
          支持
        </button>

        {/* Avatar */}
        <div className="w-8 h-8 rounded-full bg-primary-light flex items-center justify-center ml-2 border border-divider overflow-hidden">
          <span className="material-symbols-outlined text-primary" style={{ fontSize: '18px' }}>
            account_circle
          </span>
        </div>
      </div>
    </header>
  )
}
