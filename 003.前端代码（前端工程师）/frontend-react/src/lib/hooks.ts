import { useCallback, useEffect, useRef, useState } from 'react'
import * as accountsApi from '../api/accounts'
import * as categoriesApi from '../api/categories'
import * as recordsApi from '../api/records'
import * as reportsApi from '../api/reports'
import type { Account } from '../api/accounts'
import type { Category, CategoryType } from '../api/categories'
import type { ListRecordsParams, Record } from '../api/records'
import type { MonthlyReport, YearlyReport } from '../api/reports'
import { ApiError } from './api'

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
 */
function useAsync<T>(
  loader: () => Promise<T>,
  deps: unknown[],
  eventNames: string[] = [],
): AsyncState<T> & { reload: () => void } {
  const [state, setState] = useState<AsyncState<T>>({ data: null, loading: true, error: null })

  const runRef = useRef(loader)
  runRef.current = loader

  // eslint-disable-next-line react-hooks/exhaustive-deps
  useEffect(() => {
    let cancelled = false
    setState((s) => ({ ...s, loading: true, error: null }))
    runRef.current()
      .then((data) => {
        if (!cancelled) setState({ data, loading: false, error: null })
      })
      .catch((err: unknown) => {
        if (cancelled) return
        if (err instanceof ApiError) {
          setState({ data: null, loading: false, error: err })
        } else {
          setState({
            data: null,
            loading: false,
            error: new ApiError('INTERNAL', String(err), 500),
          })
        }
      })
    return () => {
      cancelled = true
    }
  }, deps)

  const reload = useCallback(() => {
    let cancelled = false
    setState((s) => ({ ...s, loading: true, error: null }))
    runRef.current()
      .then((data) => {
        if (!cancelled) setState({ data, loading: false, error: null })
      })
      .catch((err: unknown) => {
        if (cancelled) return
        if (err instanceof ApiError) {
          setState({ data: null, loading: false, error: err })
        } else {
          setState({
            data: null,
            loading: false,
            error: new ApiError('INTERNAL', String(err), 500),
          })
        }
      })
    return () => {
      cancelled = true
    }
  }, [])

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

export function useAccounts() {
  return useAsync<Account[]>(() => accountsApi.listAccounts(), [], [RECORDS_CHANGED_EVENT])
}

export function useCategories(type?: CategoryType) {
  return useAsync<Category[]>(() => categoriesApi.listCategories(type), [type])
}

export function useRecords(params: ListRecordsParams = {}) {
  const key = JSON.stringify(params)
  return useAsync<Record[]>(() => recordsApi.listRecords(params), [key], [RECORDS_CHANGED_EVENT])
}

/** 通用 POST hook；不直接 useState，自动 reload 由调用方控制。 */
export function useCreateRecord() {
  return useCallback(recordsApi.createRecord, [])
}

export function useDeleteRecord() {
  return useCallback(recordsApi.deleteRecord, [])
}

export function useMonthlyReport(month: string) {
  return useAsync<MonthlyReport>(() => reportsApi.getMonthlyReport(month), [month], [RECORDS_CHANGED_EVENT])
}

export function useYearlyReport(year: number) {
  return useAsync<YearlyReport>(() => reportsApi.getYearlyReport(year), [year], [RECORDS_CHANGED_EVENT])
}