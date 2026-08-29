import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { usePageTitle } from '../components/PageTitleContext'
import { useLanguage } from '../i18n/LanguageContext'
import { useBooks, BOOK_CHANGED_EVENT } from '../lib/hooks'
import { useCurrentBook } from '../lib/book-context'
import * as booksApi from '../api/books'
import type { Book, BookType } from '../api/books'
import { ApiError } from '../lib/api'
import { useToast } from '../components/Toast'

const TYPE_OPTIONS: { value: BookType; labelKey: string }[] = [
  { value: 'personal', labelKey: 'books.type.personal' },
  { value: 'shared', labelKey: 'books.type.shared' },
  { value: 'business', labelKey: 'books.type.business' },
]

const ROLE_LABEL_KEY: Record<Book['role'], string> = {
  owner: 'books.role.owner',
  admin: 'books.role.admin',
  editor: 'books.role.editor',
  viewer: 'books.role.viewer',
}

export function Books() {
  const { t } = useLanguage()
  const toast = useToast()
  const navigate = useNavigate()
  const { data: books, loading, error, reload } = useBooks()
  const { currentBook, setCurrentBook } = useCurrentBook()

  const [showCreate, setShowCreate] = useState(false)
  const [newName, setNewName] = useState('')
  const [newType, setNewType] = useState<BookType>('personal')
  const [newDesc, setNewDesc] = useState('')
  const [busy, setBusy] = useState(false)

  const [editing, setEditing] = useState<Book | null>(null)
  const [editDesc, setEditDesc] = useState('')

  usePageTitle(t('pageTitle.books'))

  async function handleCreate(): Promise<void> {
    if (!newName.trim()) return
    setBusy(true)
    try {
      await booksApi.createBook({ name: newName.trim(), type: newType, description: newDesc.trim() || undefined })
      setShowCreate(false)
      setNewName('')
      setNewDesc('')
      setNewType('personal')
      window.dispatchEvent(new Event(BOOK_CHANGED_EVENT))
      toast.show(t('books.create.success'))
      await reload()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('books.create.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  async function handleSwitch(uuid: string): Promise<void> {
    try {
      await setCurrentBook(uuid)
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('books.switch.failPrefix')}${msg}`)
    }
  }

  function openEdit(b: Book): void {
    setEditing(b)
    setEditDesc(b.description ?? '')
  }

  async function handleSaveEdit(): Promise<void> {
    if (!editing) return
    setBusy(true)
    try {
      await booksApi.updateBook(editing.uuid, { description: editDesc.trim() || null })
      setEditing(null)
      window.dispatchEvent(new Event(BOOK_CHANGED_EVENT))
      toast.show(t('books.edit.success'))
      await reload()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('books.edit.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  async function handleDelete(b: Book): Promise<void> {
    if (!window.confirm(t('books.delete.confirm', { name: b.name }))) return
    setBusy(true)
    try {
      await booksApi.deleteBook(b.uuid)
      window.dispatchEvent(new Event(BOOK_CHANGED_EVENT))
      toast.show(t('books.delete.success'))
      await reload()
    } catch (err) {
      const msg = err instanceof ApiError ? err.message : String(err)
      toast.show(`${t('books.delete.failPrefix')}${msg}`)
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h2 className="font-headline-md text-headline-md text-on-surface">
          {t('books.heading')}
        </h2>
        <button
          type="button"
          onClick={() => setShowCreate((v) => !v)}
          className="inline-flex items-center gap-2 px-4 py-2 bg-primary text-on-primary rounded-lg hover:bg-primary-container transition-colors font-body-md text-body-md"
        >
          <span className="material-symbols-outlined" style={{ fontSize: '20px' }}>add</span>
          {t('books.create.toggle')}
        </button>
      </div>

      {showCreate && (
        <div className="bento-item bg-bg-card p-6">
          <h3 className="font-headline-md text-headline-md text-text-primary mb-4">
            {t('books.create.title')}
          </h3>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <label className="flex flex-col gap-1">
              <span className="font-body-md text-body-md text-on-surface-variant">
                {t('books.create.name')}
              </span>
              <input
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                maxLength={50}
                className="border border-outline rounded-lg px-3 py-2 font-body-md text-body-md bg-surface-container-lowest focus:border-primary focus:ring-1 focus:ring-primary"
                placeholder={t('books.create.namePlaceholder')}
              />
            </label>
            <label className="flex flex-col gap-1">
              <span className="font-body-md text-body-md text-on-surface-variant">
                {t('books.create.type')}
              </span>
              <select
                value={newType}
                onChange={(e) => setNewType(e.target.value as BookType)}
                className="border border-outline rounded-lg px-3 py-2 font-body-md text-body-md bg-surface-container-lowest focus:border-primary"
              >
                {TYPE_OPTIONS.map((opt) => (
                  <option key={opt.value} value={opt.value}>{t(opt.labelKey)}</option>
                ))}
              </select>
            </label>
            <label className="flex flex-col gap-1 md:col-span-3">
              <span className="font-body-md text-body-md text-on-surface-variant">
                {t('books.create.description')}
              </span>
              <input
                value={newDesc}
                onChange={(e) => setNewDesc(e.target.value)}
                maxLength={200}
                className="border border-outline rounded-lg px-3 py-2 font-body-md text-body-md bg-surface-container-lowest focus:border-primary"
                placeholder={t('books.create.descPlaceholder')}
              />
            </label>
          </div>
          <div className="flex justify-end gap-2 mt-4">
            <button
              type="button"
              onClick={() => setShowCreate(false)}
              disabled={busy}
              className="px-4 py-2 border border-outline rounded-lg hover:bg-surface-container-low font-body-md text-body-md"
            >
              {t('common.cancel')}
            </button>
            <button
              type="button"
              onClick={handleCreate}
              disabled={busy || !newName.trim()}
              className="px-4 py-2 bg-primary text-on-primary rounded-lg hover:bg-primary-container font-body-md text-body-md disabled:opacity-50"
            >
              {busy ? t('common.loading') : t('common.save')}
            </button>
          </div>
        </div>
      )}

      {error && (
        <div className="bento-item bg-error-container p-4 text-error font-body-md text-body-md">
          {t('common.error')}: {error.message}
        </div>
      )}

      {loading && !books && (
        <p className="font-body-md text-body-md text-on-surface-variant">{t('common.loading')}</p>
      )}

      {books && books.length === 0 && (
        <p className="font-body-md text-body-md text-on-surface-variant">{t('books.empty')}</p>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {books?.map((b) => {
          const isCurrent = currentBook?.uuid === b.uuid
          const isOwner = b.role === 'owner'
          return (
            <div
              key={b.uuid}
              className={`bento-item bg-bg-card p-6 border ${
                isCurrent ? 'border-primary ring-2 ring-primary-light' : 'border-divider'
              }`}
            >
              <div className="flex items-start justify-between mb-3">
                <div className="flex-1 min-w-0">
                  <h3 className="font-headline-md text-headline-md text-text-primary truncate">
                    {b.name}
                  </h3>
                  <p className="font-body-md text-body-md text-on-surface-variant truncate">
                    {b.description || t('books.noDesc')}
                  </p>
                </div>
                {b.isDefault && (
                  <span className="ml-2 px-2 py-0.5 rounded-full bg-primary-light text-primary text-xs font-semibold flex-shrink-0">
                    {t('books.badge.default')}
                  </span>
                )}
              </div>
              <div className="flex items-center gap-2 mb-4 text-sm text-on-surface-variant">
                <span className="material-symbols-outlined" style={{ fontSize: '16px' }}>
                  {b.type === 'shared' ? 'group' : b.type === 'business' ? 'business_center' : 'person'}
                </span>
                <span>{t(`books.type.${b.type}`)}</span>
                <span className="text-divider">·</span>
                <span>{t(ROLE_LABEL_KEY[b.role])}</span>
              </div>
              <div className="flex flex-wrap gap-2">
                {!isCurrent && (
                  <button
                    type="button"
                    onClick={() => handleSwitch(b.uuid)}
                    className="px-3 py-1.5 text-sm border border-primary text-primary rounded-lg hover:bg-primary-light transition-colors"
                  >
                    {t('books.action.switch')}
                  </button>
                )}
                {isCurrent && (
                  <span className="px-3 py-1.5 text-sm bg-primary-light text-primary rounded-lg font-semibold">
                    {t('books.badge.current')}
                  </span>
                )}
                <button
                  type="button"
                  onClick={() => navigate(`/books/${b.uuid}/members`)}
                  className="px-3 py-1.5 text-sm border border-outline rounded-lg hover:bg-surface-container-low transition-colors"
                >
                  {t('books.action.members')}
                </button>
                {isOwner && (
                  <>
                    <button
                      type="button"
                      onClick={() => openEdit(b)}
                      className="px-3 py-1.5 text-sm border border-outline rounded-lg hover:bg-surface-container-low transition-colors"
                    >
                      {t('common.edit')}
                    </button>
                    {!b.isDefault && (
                      <button
                        type="button"
                        onClick={() => handleDelete(b)}
                        disabled={busy}
                        className="px-3 py-1.5 text-sm border border-error text-error rounded-lg hover:bg-error hover:text-white transition-colors disabled:opacity-50"
                      >
                        {t('common.delete')}
                      </button>
                    )}
                  </>
                )}
              </div>
            </div>
          )
        })}
      </div>

      {editing && (
        <div className="fixed inset-0 z-50 bg-black/40 flex items-center justify-center p-4">
          <div className="bg-bg-card rounded-xl p-6 w-full max-w-md">
            <h3 className="font-headline-md text-headline-md text-text-primary mb-4">
              {t('books.edit.title', { name: editing.name })}
            </h3>
            <label className="flex flex-col gap-1 mb-4">
              <span className="font-body-md text-body-md text-on-surface-variant">
                {t('books.create.description')}
              </span>
              <input
                value={editDesc}
                onChange={(e) => setEditDesc(e.target.value)}
                className="border border-outline rounded-lg px-3 py-2 font-body-md text-body-md bg-surface-container-lowest focus:border-primary"
                maxLength={200}
              />
            </label>
            <div className="flex justify-end gap-2">
              <button
                type="button"
                onClick={() => setEditing(null)}
                className="px-4 py-2 border border-outline rounded-lg font-body-md text-body-md"
              >
                {t('common.cancel')}
              </button>
              <button
                type="button"
                onClick={handleSaveEdit}
                disabled={busy}
                className="px-4 py-2 bg-primary text-on-primary rounded-lg font-body-md text-body-md disabled:opacity-50"
              >
                {t('common.save')}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
