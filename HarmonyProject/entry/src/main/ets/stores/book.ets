/**
 * 账本 Store:对齐 uniapp stores/book.ts 1:1。
 * ponytail: 加 subscribe 让页面在 currentId 变化时主动重拉数据,
 * 模拟 uniapp watch([auth.token, book.current], ...) 的效果。
 */
import { AppStorageV2 } from '@kit.ArkUI'
import preferences from '@ohos.data.preferences'
import { getCtx } from '../utils/context'
import { logger, TAGS } from '../utils/logger'
import type { Book } from '../model/Types'
import { listBooks } from '../api/books'
import { getAuth } from './auth'

const STORE = 'qingzhang-book'
let prefs: preferences.Preferences | null = null
async function getPrefs(): Promise<preferences.Preferences> {
  if (prefs) return prefs
  prefs = await preferences.getPreferences(getCtx(), STORE)
  return prefs
}

@ObservedV2
export class BookStore {
  @Trace books: Book[] = []
  @Trace currentId: string = ''
  @Trace loading: boolean = false
  @Trace ready: boolean = false

  private listeners: Array<() => void> = []
  subscribe(fn: () => void): () => void {
    this.listeners.push(fn)
    return () => {
      const i = this.listeners.indexOf(fn)
      if (i >= 0) this.listeners.splice(i, 1)
    }
  }
  private fire(): void {
    for (const fn of this.listeners.slice()) {
      try { fn() } catch { /* 容忍 */ }
    }
  }

  get current(): Book | null {
    return this.books.find(b => b.uuid === this.currentId) ?? null
  }

  async hydrate(): Promise<void> {
    try {
      const p = await getPrefs()
      this.currentId = await p.get('currentId', '') as string
    } catch { /* ignore */ }
    this.ready = true
  }

  async setCurrent(uuid: string): Promise<void> {
    this.currentId = uuid
    const p = await getPrefs()
    await p.put('currentId', uuid)
    await p.flush()
    this.fire()
  }

  async reload(): Promise<void> {
    if (!getAuth().token) return
    this.loading = true
    try {
      const list: Book[] = await listBooks()
      const raw: Book[] = list ?? []
      const valid: Book[] = []
      for (const b of raw) if (b && !!b.uuid) valid.push(b)
      this.books = valid
      if (this.books.length === 0) {
        this.fire()
        return
      }
      const exist = this.books.find(b => b.uuid === this.currentId)
      if (!exist) {
        const def = this.books.find(b => b.isDefault) ?? this.books[0]
        this.currentId = def.uuid
      }
      this.fire()
      logger.info(TAGS.STORE, `reload books=${this.books.length} currentId=${this.currentId}`)
    } finally {
      this.loading = false
    }
  }
}

export const bookStore: BookStore = AppStorageV2.connect(BookStore, 'bookStore', () => new BookStore())!
export function getBook(): BookStore { return bookStore }
