/**
 * HTTP 客户端:对齐 uniapp api/http.ts 1:1。
 * ponytail: 用 @kit.NetworkKit.http,内置 1401 拦截 + navGraceUntil。
 */
import { http } from '@kit.NetworkKit'
import { ApiError } from '../model/Types'
import { getAuth } from '../stores/auth'
import { getToast } from '../stores/toast'

const BASE_URL = 'http://10.0.2.2:8080/api'
let navGraceUntil = 0

export function setNavGrace(ms: number): void { navGraceUntil = Date.now() + ms }
export function isInGrace(): boolean { return Date.now() < navGraceUntil }

type AuthInvalidListener = () => void
const authInvalidListeners: AuthInvalidListener[] = []
export function onAuthInvalid(fn: AuthInvalidListener): () => void {
  authInvalidListeners.push(fn)
  return () => {
    const i = authInvalidListeners.indexOf(fn)
    if (i >= 0) authInvalidListeners.splice(i, 1)
  }
}

function fireAuthInvalid(): void {
  if (isInGrace()) return
  for (const fn of authInvalidListeners) { try { fn() } catch { /* noop */ } }
}

export interface RequestOptions {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'
  data?: Object | string
  headers?: Record<string, string>
  silent401?: boolean
}

function toMethod(m: string | undefined): http.RequestMethod {
  switch (m) {
    case 'POST': return http.RequestMethod.POST
    case 'PUT': return http.RequestMethod.PUT
    case 'DELETE': return http.RequestMethod.DELETE
    case 'PATCH': return http.RequestMethod.PATCH
    case 'HEAD': return http.RequestMethod.HEAD
    case 'OPTIONS': return http.RequestMethod.OPTIONS
    default: return http.RequestMethod.GET
  }
}

function pickMessage(body: Record<string, Object> | null, fallback: string): string {
  const m = body?.['message']
  return typeof m === 'string' ? m : fallback
}

function pickCode(body: Record<string, Object> | null, fallback: number): number {
  const c = body?.['code']
  return typeof c === 'number' ? c : fallback
}

export async function request<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const auth = getAuth()
  const url = path.startsWith('http') ? path : `${BASE_URL}${path}`
  const headers: Record<string, string> = { 'Content-Type': 'application/json' }
  if (opts.headers) {
    for (const k of Object.keys(opts.headers)) {
      const v = opts.headers[k]
      if (typeof v === 'string') headers[k] = v
    }
  }
  if (auth.token) headers['Authorization'] = `Bearer ${auth.token}`

  const httpRequest = http.createHttp()
  try {
    const extraData = typeof opts.data === 'string'
      ? opts.data
      : JSON.stringify(opts.data ?? {})
    const response = await httpRequest.request(url, {
      method: toMethod(opts.method),
      header: headers,
      extraData: extraData,
      expectDataType: http.HttpDataType.OBJECT,
      connectTimeout: 15000,
      readTimeout: 15000,
    })
    const status = response.responseCode
    const body = response.result as Record<string, Object> | null
    if (status === 401) {
      if (!opts.silent401) fireAuthInvalid()
      throw new ApiError(1401, pickMessage(body, '未登录'), status)
    }
    if (status < 200 || status >= 300) {
      throw new ApiError(pickCode(body, status), pickMessage(body, `HTTP ${status}`), status)
    }
    const code = body?.['code']
    if (typeof code === 'number' && code !== 0 && code !== 200) {
      throw new ApiError(code, pickMessage(body, 'request failed'), status)
    }
    const data: Object | undefined = body?.['data']
    if (data !== undefined && data !== null) {
      return data as T
    }
    return body as T
  } finally {
    httpRequest.destroy()
  }
}

let silent = false
export async function runSilent<T>(fn: () => Promise<T>): Promise<T | undefined> {
  const prev = silent
  silent = true
  try { return await fn() } catch {
    return undefined
  } finally { silent = prev }
}

export function showError(e: Error): void {
  if (silent) return
  const msg = e instanceof ApiError ? e.message : (e?.message ?? '网络异常')
  const toast = getToast()
  if (toast) toast.show(msg)
}