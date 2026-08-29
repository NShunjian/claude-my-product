import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import * as booksApi from '../api/books'
import type { Book } from '../api/books'

const ACTIVE_BOOK_KEY = 'qz_active_book'

export interface BookContextValue {
  books: Book[]
  currentBook: Book | null
  /** 切换活跃账本(同时写 localStorage + 通知后端) */
  setCurrentBook: (uuid: string) => Promise<void>
  loading: boolean
  error: string | null
  /** 强制刷新账本列表(创建/删除/邀请成员后调用) */
  reload: () => Promise<void>
}

const BookContext = createContext<BookContextValue | undefined>(undefined)

/**
 * 当前账本解析规则(优先级从高到低):
 *   1. localStorage 'qz_active_book' 是否仍可访问
 *   2. 用户默认账本(后端返回 isDefault=true)
 *   3. 第一本账本
 *   4. null(用户没账本,几乎不会出现:V1 注册时会自动建默认账本)
 */
function pickCurrent(books: Book[], savedUuid: string | null): Book | null {
  if (books.length === 0) return null
  if (savedUuid) {
    const hit = books.find((b) => b.uuid === savedUuid && !b.isArchived)
    if (hit) return hit
  }
  const def = books.find((b) => b.isDefault)
  if (def) return def
  const first = books.find((b) => !b.isArchived)
  return first ?? books[0]
}

export function BookProvider({ children }: { children: ReactNode }) {
  const [books, setBooks] = useState<Book[]>([])
  const [currentBook, setCurrentBookState] = useState<Book | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async (): Promise<void> => {
    setError(null)
    try {
      const list = await booksApi.listBooks()
      setBooks(list)
      const saved = localStorage.getItem(ACTIVE_BOOK_KEY)
      setCurrentBookState((prev) => pickCurrent(list, saved ?? prev?.uuid ?? null))
    } catch (err) {
      setError(err instanceof Error ? err.message : 'failed to load books')
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    void load()
  }, [load])

  const setCurrentBook = useCallback(
    async (uuid: string): Promise<void> => {
      const target = books.find((b) => b.uuid === uuid)
      if (!target) {
        throw new Error(`book not found in current list: ${uuid}`)
      }
      localStorage.setItem(ACTIVE_BOOK_KEY, uuid)
      setCurrentBookState(target)
      // 后端兼容调用:owner 写入 is_default,其他角色也接受 200;失败不影响前端
      try {
        await booksApi.setDefaultBook(uuid)
      } catch (err) {
        console.warn('[setDefaultBook] 后端同步失败,已写入 localStorage', err)
      }
      // 重新拉一次让 role/isDefault 等服务端字段与本地状态对齐
      void load()
    },
    [books, load],
  )

  const value = useMemo<BookContextValue>(
    () => ({ books, currentBook, setCurrentBook, loading, error, reload: load }),
    [books, currentBook, setCurrentBook, loading, error, load],
  )

  return <BookContext.Provider value={value}>{children}</BookContext.Provider>
}

export function useCurrentBook(): BookContextValue {
  const ctx = useContext(BookContext)
  if (!ctx) {
    throw new Error('useCurrentBook must be used within a BookProvider')
  }
  return ctx
}
