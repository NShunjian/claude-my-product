import { useCallback, useEffect, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import { usePageTitle } from '../components/PageTitleContext'
import { useLanguage } from '../i18n/LanguageContext'
import { useToast } from '../components/Toast'
import { useAuth } from '../auth/AuthContext'
import * as booksApi from '../api/books'
import type { Book, BookMember, BookRole } from '../api/books'
import { ApiError } from '../lib/api'
import { useCurrentBook } from '../lib/book-context'

type InvitableRole = Exclude<BookRole, 'owner'>
const ROLES: InvitableRole[] = ['admin', 'editor', 'viewer']

export function BookMembers() {
  const { uuid } = useParams<{ uuid: string }>()
  const { t } = useLanguage()
  const toast = useToast()
  const navigate = useNavigate()
  const { user: me } = useAuth()
  const { reload: reloadBooks } = useCurrentBook()

  const [book, setBook] = useState<Book | null>(null)
  const [members, setMembers] = useState<BookMember[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

  const [showInvite, setShowInvite] = useState(false)
  const [inviteUsername, setInviteUsername] = useState('')
  const [inviteRole, setInviteRole] = useState<InvitableRole>('editor')

  usePageTitle(t('pageTitle.bookMembers'))

  const load = useCallback(async () => {
    if (!uuid) return
    setError(null)
    setLoading(true)
    try {
      const [b, ms] = await Promise.all([booksApi.getBook(uuid), booksApi.listMembers(uuid)])
      setBook(b)
      setMembers(ms)
    } catch (err) {
      setError(err instanceof ApiError ? err.message : String(err))
    } finally {
      setLoading(false)
    }
  }, [uuid])

  useEffect(() => {
    void load()
  }, [load])

  if (!uuid) return null

  const isOwner = book?.role === 'owner'

  async function handleInvite(): Promise<void> {
    if (!inviteUsername.trim()) return
    setBusy(true)
    try {
      await booksApi.addMember(uuid!, { username: inviteUsername.trim(), role: inviteRole })
      setShowInvite(false)
      setInviteUsername('')
      setInviteRole('editor')
      toast.show(t('bookMembers.invite.success'))
      await load()
      void reloadBooks()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('bookMembers.invite.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  async function handleRoleChange(m: BookMember, role: InvitableRole): Promise<void> {
    setBusy(true)
    try {
      await booksApi.updateMemberRole(uuid!, m.userUuid, { role })
      toast.show(t('bookMembers.role.success'))
      await load()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('bookMembers.role.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  async function handleRemove(m: BookMember): Promise<void> {
    if (!window.confirm(t('bookMembers.remove.confirm', { name: m.username }))) return
    setBusy(true)
    try {
      await booksApi.removeMember(uuid!, m.userUuid)
      toast.show(t('bookMembers.remove.success'))
      await load()
      void reloadBooks()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('bookMembers.remove.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => navigate('/books')}
          className="p-1 rounded-full hover:bg-surface-container text-on-surface-variant"
          aria-label={t('common.back')}
        >
          <span className="material-symbols-outlined">arrow_back</span>
        </button>
        <h2 className="font-headline-md text-headline-md text-on-surface">
          {t('bookMembers.heading', { name: book?.name ?? '…' })}
        </h2>
      </div>

      <div className="flex items-center justify-between">
        <p className="font-body-md text-body-md text-on-surface-variant">
          {t('bookMembers.count', { count: members.length })}
        </p>
        {isOwner && (
          <button
            type="button"
            onClick={() => setShowInvite((v) => !v)}
            className="inline-flex items-center gap-2 px-4 py-2 bg-primary text-on-primary rounded-lg hover:bg-primary-container transition-colors font-body-md text-body-md"
          >
            <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>person_add</span>
            {t('bookMembers.invite.toggle')}
          </button>
        )}
      </div>

      {showInvite && (
        <div className="bento-item bg-bg-card p-6">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">
            {t('bookMembers.invite.title')}
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <label className="flex flex-col gap-1 md:col-span-2">
              <span className="font-body-md text-body-md text-on-surface-variant">
                {t('bookMembers.invite.username')}
              </span>
              <input
                value={inviteUsername}
                onChange={(e) => setInviteUsername(e.target.value)}
                className="border border-outline rounded-lg px-3 py-2 font-body-md text-body-md bg-surface-container-lowest focus:border-primary"
                placeholder={t('bookMembers.invite.usernamePlaceholder')}
              />
            </label>
            <label className="flex flex-col gap-1">
              <span className="font-body-md text-body-md text-on-surface-variant">
                {t('bookMembers.invite.role')}
              </span>
              <select
                value={inviteRole}
                onChange={(e) => setInviteRole(e.target.value as InvitableRole)}
                className="border border-outline rounded-lg px-3 py-2 font-body-md text-body-md bg-surface-container-lowest focus:border-primary"
              >
                {ROLES.map((r) => (
                  <option key={r} value={r}>{t(`books.role.${r}`)}</option>
                ))}
              </select>
            </label>
          </div>
          <div className="flex justify-end gap-2 mt-4">
            <button
              type="button"
              onClick={() => setShowInvite(false)}
              disabled={busy}
              className="px-4 py-2 border border-outline rounded-lg font-body-md text-body-md"
            >
              {t('common.cancel')}
            </button>
            <button
              type="button"
              onClick={handleInvite}
              disabled={busy || !inviteUsername.trim()}
              className="px-4 py-2 bg-primary text-on-primary rounded-lg font-body-md text-body-md disabled:opacity-50"
            >
              {t('bookMembers.invite.submit')}
            </button>
          </div>
        </div>
      )}

      {error && (
        <div className="bento-item bg-error-container p-4 text-error font-body-md text-body-md">
          {t('common.error')}: {error}
        </div>
      )}

      {loading && (
        <p className="font-body-md text-body-md text-on-surface-variant">{t('common.loading')}</p>
      )}

      <div className="bento-item bg-bg-card divide-y divide-divider">
        {members.map((m) => {
          const isMe = m.userUuid === me?.uuid
          return (
            <div key={m.userUuid} className="flex items-center gap-4 px-6 py-4">
              <div className="w-10 h-10 rounded-full bg-primary-light flex items-center justify-center flex-shrink-0 overflow-hidden">
                {m.avatar ? (
                  <img src={m.avatar} alt={m.username} className="w-full h-full object-cover" />
                ) : (
                  <span className="material-symbols-outlined text-primary">account_circle</span>
                )}
              </div>
              <div className="flex-1 min-w-0">
                <p className="font-body-md text-body-md text-text-primary font-semibold truncate">
                  {m.displayName || m.username}
                  {isMe && <span className="ml-2 text-xs text-primary">{t('bookMembers.you')}</span>}
                </p>
                <p className="font-body-sm text-body-sm text-on-surface-variant truncate">
                  @{m.username}
                </p>
              </div>
              <div className="flex items-center gap-2 flex-shrink-0">
                {isOwner && m.role !== 'owner' ? (
                  <select
                    value={m.role}
                    onChange={(e) => handleRoleChange(m, e.target.value as InvitableRole)}
                    disabled={busy}
                    className="border border-outline rounded-lg px-3 py-1.5 text-sm bg-surface-container-lowest focus:border-primary disabled:opacity-50"
                  >
                    {ROLES.map((r) => (
                      <option key={r} value={r}>{t(`books.role.${r}`)}</option>
                    ))}
                  </select>
                ) : (
                  <span className="px-3 py-1.5 text-sm bg-surface-container-low rounded-lg text-text-primary">
                    {t(`books.role.${m.role}`)}
                  </span>
                )}
                {isOwner && m.role !== 'owner' && (
                  <button
                    type="button"
                    onClick={() => handleRemove(m)}
                    disabled={busy}
                    className="px-3 py-1.5 text-sm border border-error text-error rounded-lg hover:bg-error hover:text-white transition-colors disabled:opacity-50"
                  >
                    {t('bookMembers.remove.button')}
                  </button>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
