import { useContext } from 'react'
import { Link, useLocation } from 'react-router-dom'
import { PageTitleContext } from './PageTitleContext'
import { useAuth } from '../auth/AuthContext'
import { useLanguage } from '../i18n/LanguageContext'
import { useCurrentBook } from '../lib/book-context'

export function TopBar() {
  const { title, backTo, backLabel } = useContext(PageTitleContext)
  const { user } = useAuth()
  const { t } = useLanguage()
  const location = useLocation()
  const { currentBook, books, setCurrentBook, loading: booksLoading } = useCurrentBook()
  // Hide back link once we've already reached the back target (e.g. after
  // clicking ← 首页 and landing on /). Prevents stale back state from leaking
  // across pages.
  const showBack = !!backTo && backTo !== location.pathname

  async function onBookChange(uuid: string): Promise<void> {
    try {
      await setCurrentBook(uuid)
    } catch (err) {
      console.error('[TopBar] switch book failed', err)
    }
  }

  return (
    <header
      className={`sticky top-0 z-30 flex justify-between items-center h-16 px-8 max-w-full border-b bg-bg-card border-divider`}
    >
      <div className="flex items-center gap-4 flex-1">
        {showBack && (
          <Link
            to={backTo}
            className="text-on-surface-variant hover:text-primary transition-colors flex items-center gap-1 p-1 rounded-full hover:bg-surface-container"
          >
            <span className="material-symbols-outlined text-2xl">arrow_back</span>
            {backLabel && (
              <span className="font-body-md text-body-md ml-1 text-text-primary">
                {backLabel}
              </span>
            )}
          </Link>
        )}
        <h2 className="font-display-lg text-display-lg text-primary hidden md:block">{title}</h2>
      </div>

      <div className="flex items-center gap-4">
        {/* 当前账本选择器 */}
        {currentBook && (
          <div className="relative">
            <span
              className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-xl pointer-events-none"
              aria-hidden="true"
            >
              menu_book
            </span>
            <select
              value={currentBook.uuid}
              onChange={(e) => onBookChange(e.target.value)}
              disabled={booksLoading || books.length === 0}
              aria-label={t('topbar.bookSwitcher.label')}
              className="appearance-none pl-10 pr-9 py-2 bg-surface-container-lowest border border-divider rounded-full font-body-md text-body-md focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary text-text-primary cursor-pointer max-w-[200px]"
            >
              {books.map((b) => (
                <option key={b.uuid} value={b.uuid}>
                  {b.name}
                </option>
              ))}
            </select>
            <span
              className="material-symbols-outlined absolute right-2 top-1/2 -translate-y-1/2 pointer-events-none text-on-surface-variant"
              style={{ fontSize: '20px' }}
            >
              expand_more
            </span>
          </div>
        )}
        {/* Search */}
        <div className="relative hidden md:block">
          <span className="material-symbols-outlined absolute left-3 top-1/2 -translate-y-1/2 text-on-surface-variant text-xl">
            search
          </span>
          <input
            className="pl-10 pr-4 py-2 bg-surface-container-lowest border border-divider rounded-full font-body-md text-body-md focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary w-64 transition-colors text-text-primary placeholder-outline"
            placeholder={t('common.search') + '...'}
            type="text"
          />
        </div>

        {/* Notifications */}
        <button
          type="button"
          aria-label={t('topbar.notifications')}
          className="text-on-surface-variant hover:text-primary transition-colors opacity-80 hover:opacity-100"
        >
          <span className="material-symbols-outlined text-xl">notifications</span>
        </button>

        {/* Help icon */}
        <button
          type="button"
          className="text-on-surface-variant hover:text-primary transition-colors opacity-80 hover:opacity-100"
        >
          <span className="material-symbols-outlined text-xl">help</span>
        </button>

        {/* Help text */}
        <button
          type="button"
          className="font-body-md text-body-md text-on-surface-variant hover:text-primary transition-colors hidden sm:block"
        >
          {t('topbar.help')}
        </button>

        {/* Avatar */}
        <div className="w-8 h-8 rounded-full bg-primary-light flex items-center justify-center ml-2 border border-divider overflow-hidden">
          {user?.avatar ? (
            <img
              src={user.avatar}
              alt={t('topbar.avatarAlt')}
              className="w-full h-full object-cover rounded-full"
            />
          ) : (
            <span className="material-symbols-outlined text-primary" style={{ fontSize: '18px' }}>
              account_circle
            </span>
          )}
        </div>
      </div>
    </header>
  )
}