const API_BASE: string =
  (import.meta.env.VITE_API_BASE as string | undefined) ?? 'http://localhost:4001'

const TOKEN_KEY = 'qz_token'

export function getToken(): string | null {
  return uni.getStorageSync(TOKEN_KEY) ?? null
}

export class ApiError extends Error {
  code: number | string
  status: number
  constructor(code: number | string, message: string, status: number) {
    super(message)
    this.code = code
    this.status = status
    this.name = 'ApiError'
  }
}

type AuthInvalidListener = () => void
const authInvalidListeners = new Set<AuthInvalidListener>()
export function onAuthInvalid(fn: AuthInvalidListener): () => void {
  authInvalidListeners.add(fn)
  return () => { authInvalidListeners.delete(fn) }
}

// 初始化阶段用 — H5 刷新时 token 可能已失效,如果同步触发 onInvalid 会把当前页的用户
// 踢回登录页(典型场景:刷新资料编辑页 → App.vue onLaunch → auth.me() → 1401 → 跳登录)。
// 这里只是压制 1401 的踢人动作,token 仍留着,等用户主动操作时再正常处理。
let suppressAuthInvalid = false
export async function runSilent<T>(fn: () => Promise<T>): Promise<T> {
  const prev = suppressAuthInvalid
  suppressAuthInvalid = true
  try {
    return await fn()
  } finally {
    suppressAuthInvalid = prev
  }
}

// 浏览器级导航后的被动加载窗口 — 刷新 / history.back()/forward() 触发 pageshow + popstate,
// 这期间触发的 API 调用(典型场景:onShow → load → 1401)不该把用户踢回登录页。
// 用户真正主动操作(点保存/记一笔/导出等)通常发生在几秒阅读之后,3 秒窗口足够覆盖首屏所有
// 同步触发的被动 API 调用,又不会误压主动操作。
const NAV_GRACE_MS = 3000
let navGraceUntil = 0
if (typeof window !== 'undefined') {
  const bump = () => { navGraceUntil = Date.now() + NAV_GRACE_MS }
  window.addEventListener('pageshow', bump)
  window.addEventListener('popstate', bump)
}

interface ApiEnvelope<T> { code: number; message: string; data?: T }

export async function request<T>(path: string, options: {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'
  data?: unknown
  header?: Record<string, string>
} = {}): Promise<T> {
  const headers: Record<string, string> = { ...(options.header ?? {}) }
  if (options.data !== undefined && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json'
  }
  const token = getToken()
  if (token && !headers.Authorization) headers.Authorization = `Bearer ${token}`

  const res = await new Promise<UniApp.RequestSuccessCallbackResult>((resolve, reject) => {
    uni.request({
      url: API_BASE + path,
      method: options.method ?? 'GET',
      data: options.data,
      header: headers,
      success: resolve,
      fail: reject,
    })
  })

  const env = (typeof res.data === 'object' && res.data !== null
    ? res.data : {}) as Partial<ApiEnvelope<T>>
  const code = env.code ?? 'INTERNAL'
  const message = env.message ?? `HTTP ${res.statusCode}`

  if (code === 1401 && !suppressAuthInvalid && Date.now() >= navGraceUntil) {
    for (const fn of authInvalidListeners) {
      try { fn() } catch (e) { console.error('[authInvalid]', e) }
    }
  }

  if (res.statusCode < 200 || res.statusCode >= 300 || code !== 0) {
    throw new ApiError(code as number | string, message, res.statusCode)
  }
  return env.data as T
}
