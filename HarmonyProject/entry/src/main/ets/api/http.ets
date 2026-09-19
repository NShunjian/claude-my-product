/**
 * HTTP 客户端:对齐 uniapp api/http.ts 1:1。
 * ponytail: 用 @kit.NetworkKit.http,内置 1401 拦截 + navGraceUntil,全量请求/响应走 logger 打 Net tag。
 */
import { http } from '@kit.NetworkKit'
import { ApiError } from '../model/Types'
import { getAuth } from '../stores/auth'
import { getToast } from '../stores/toast'
import { logger, TAGS } from '../utils/logger'

// ponytail: ArkTS 不允许 inline object literal 当 logger detail 传,起一个具名 class 让类型显式
class HttpLogDetail {
  body: string = ''
  hdr: string = ''
}

// 与 uniapp api/http.ts 口径一致:LAN_IP 来自仓库根 .env(随工作区统一),路径前缀 /api 与 Spring Boot 路由对齐。
// 真机/模拟器都走 LAN IP;改网时只改仓库根 .env 的 LAN_IP 一处。
const BASE_URL = 'http://192.168.31.46:4001/api'
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

  const method = toMethodStr(opts.method)
  // GET / HEAD 不带 body,后端对空 body {} 拒 400
  const extraData: string = (method === 'GET' || method === 'HEAD' || opts.data === undefined)
    ? ''
    : (typeof opts.data === 'string' ? opts.data : JSON.stringify(opts.data))
  const startedAt = Date.now()
  const reqDetail: HttpLogDetail = new HttpLogDetail()
  reqDetail.body = extraData
  reqDetail.hdr = JSON.stringify(headers)
  logger.debug(TAGS.NET, `→ ${method} ${path}`, reqDetail)

  const httpRequest = http.createHttp()
  try {
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
    const elapsed = Date.now() - startedAt
    logger.info(TAGS.NET, `← ${status} ${method} ${path} (${elapsed}ms)`, body === null ? 'null' : body)
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
  } catch (e) {
    const elapsed = Date.now() - startedAt
    const err: Error = e instanceof Error ? e : new Error(String(e))
    logger.error(TAGS.NET, `✗ ${method} ${path} (${elapsed}ms)`, err.message)
    throw err
  } finally {
    httpRequest.destroy()
  }
}

function toMethodStr(m: string | undefined): string {
  switch (m) {
    case 'POST': return 'POST'
    case 'PUT': return 'PUT'
    case 'DELETE': return 'DELETE'
    case 'PATCH': return 'PATCH'
    case 'HEAD': return 'HEAD'
    case 'OPTIONS': return 'OPTIONS'
    default: return 'GET'
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