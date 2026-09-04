import { useCallback, useEffect, useRef, useState } from 'react'
import * as accountsApi from '../api/accounts'
import * as booksApi from '../api/books'
import * as categoriesApi from '../api/categories'
import * as recordsApi from '../api/records'
import * as reportsApi from '../api/reports'
import type { Account } from '../api/accounts'
import type { Book } from '../api/books'
import type { Category, CategoryType } from '../api/categories'
import type { ListRecordsParams, Record } from '../api/records'
import type { MonthlyReport, YearlyReport } from '../api/reports'
import { ApiError } from './api'
import { useCurrentBook } from './book-context'

interface AsyncState<T> {
  data: T | null
  loading: boolean
  error: ApiError | null
}

/**
 * 通用 async hook：useEffect 触发 fetch，提供 reload() 手动刷新。
 * 401 会被 request() 抛 ApiError，调用方决定如何处理（一般不需额外动作：AuthContext 初始化已做过）。
 *
 * 可监听 window 事件名（eventNames）以触发 reload：记账成功后页面应该刷新流水/账户余额。
 *
 * 实现要点：用单调递增 token 让过期 in-flight 自动失效，避免旧请求覆盖新 state。
 */
function useAsync<T>(
  loader: () => Promise<T>,
  deps: unknown[],
  eventNames: string[] = [],
): AsyncState<T> & { reload: () => void } {
  const [state, setState] = useState<AsyncState<T>>({ data: null, loading: true, error: null })

  const runRef = useRef(loader)
  runRef.current = loader
  const tokenRef = useRef(0)

  const execute = useCallback(() => {
    const myToken = ++tokenRef.current
    setState((s) => ({ ...s, loading: true, error: null }))
    runRef.current()
      .then((data) => {
        if (myToken !== tokenRef.current) return  // 已被新请求 / 重载覆盖
        setState({ data, loading: false, error: null })
      })
      .catch((err: unknown) => {
        if (myToken !== tokenRef.current) return
        // 保留旧 data —— 比列表突然清空更友好;reload 失败时用户至少还能看到 stale 数据。
        // 调用方可在 useEffect / render 里读 error 字段决定是否 toast 提示。
        const apiErr = err instanceof ApiError ? err : new ApiError('INTERNAL', String(err), 500)
        setState((s) => ({ ...s, loading: false, error: apiErr }))
      })
  }, [])

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    execute()
  }, deps)

  const reload = execute

  // 监听全局事件触发 reload
  useEffect(() => {
    if (eventNames.length === 0) return
    const handler = () => reload()
    for (const name of eventNames) {
      window.addEventListener(name, handler)
    }
    return () => {
      for (const name of eventNames) {
        window.removeEventListener(name, handler)
      }
    }
  }, [reload, eventNames])

  return { ...state, reload }
}

/** 记录变更事件名，记账成功后由调用方 dispatch */
export const RECORDS_CHANGED_EVENT = 'qingzhang:records-changed'

/** 账本变更事件名:创建/删除/邀请成员/切账本成功后 dispatch;hook 监听后 reload */
export const BOOK_CHANGED_EVENT = 'qingzhang:book-changed'

export function useAccounts() {
  const { currentBook } = useCurrentBook()
  return useAsync<Account[]>(
    () => accountsApi.listAccounts({ bookId: currentBook?.uuid }),
    [currentBook?.uuid],
    [RECORDS_CHANGED_EVENT, 'qingzhang:book-changed'],
  )
}

export function useCategories(type?: CategoryType) {
  // 自定义分类是用户级全局,跟当前账本无关
  return useAsync<Category[]>(() => categoriesApi.listCategories(type), [type])
}

export function useRecords(params: ListRecordsParams = {}) {
  const { currentBook } = useCurrentBook()
  // 调用方传过来的 bookId 优先;否则跟随当前账本
  const bookId = params.bookId ?? currentBook?.uuid
  const merged = { ...params, bookId }
  const key = JSON.stringify(merged)
  return useAsync<Record[]>(
    () => recordsApi.listRecords(merged),
    [key],
    [RECORDS_CHANGED_EVENT, 'qingzhang:book-changed'],
  )
}

/** 通用 POST hook；不直接 useState，自动 reload 由调用方控制。 */
export function useCreateRecord() {
  const { currentBook } = useCurrentBook()
  return useCallback((input: Parameters<typeof recordsApi.createRecord>[0]) => {
    // 没显式传 bookId 时注入当前账本
    const withBook =
      'bookId' in input && input.bookId
        ? input
        : ({ ...input, bookId: currentBook?.uuid } as Parameters<typeof recordsApi.createRecord>[0])
    return recordsApi.createRecord(withBook)
  }, [currentBook?.uuid])
}

export function useDeleteRecord() {
  return useCallback(recordsApi.deleteRecord, [])
}

export function useMonthlyReport(month: string) {
  const { currentBook } = useCurrentBook()
  return useAsync<MonthlyReport>(
    () => reportsApi.getMonthlyReport(month, currentBook?.uuid),
    [month, currentBook?.uuid],
    [RECORDS_CHANGED_EVENT, 'qingzhang:book-changed'],
  )
}

export function useYearlyReport(year: number) {
  const { currentBook } = useCurrentBook()
  return useAsync<YearlyReport>(
    () => reportsApi.getYearlyReport(year, currentBook?.uuid),
    [year, currentBook?.uuid],
    [RECORDS_CHANGED_EVENT, 'qingzhang:book-changed'],
  )
}

/**
 * 账本列表(供 Sidebar / TopBar / Books 页用)。
 * 监听 'qingzhang:book-changed' 事件:切账本 / 创建 / 删除 / 邀请成员后由调用方 dispatch。
 */
export function useBooks() {
  return useAsync<Book[]>(
    () => booksApi.listBooks(),
    [],
    ['qingzhang:book-changed'],
  )
}