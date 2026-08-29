export const API_BASE: string =
  import.meta.env.VITE_API_BASE ?? 'http://localhost:4001'

const TOKEN_KEY = 'qz_token'

/** 获取当前保存的 JWT；调用方一般无需直接使用，request() 会自动注入。 */
export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
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

/**
 * 401 全局回调:任何 request() 收到 401 时触发。
 * AuthContext 注册并清 token + user,然后 ProtectedRoute 自然把用户踢回 /login。
 */
type AuthInvalidListener = () => void

const authInvalidListeners = new Set<AuthInvalidListener>()

export function onAuthInvalid(listener: AuthInvalidListener): () => void {
  authInvalidListeners.add(listener)
  return () => {
    authInvalidListeners.delete(listener)
  }
}

function notifyAuthInvalid(): void {
  for (const listener of authInvalidListeners) {
    try {
      listener()
    } catch (err) {
      console.error('[authInvalid] listener threw', err)
    }
  }
}

/** 后端统一信封:{code, message, data?}。code===0 表示成功。 */
interface ApiEnvelope<T> {
  code: number
  message: string
  data?: T
}

/**
 * 统一 fetch 封装：
 * - 自动注入 Authorization: Bearer <token>
 * - 自动设置 Content-Type: application/json
 * - 后端返 {code,message,data} 信封:成功取 data 返给调用方;code!=0 或 HTTP 非 2xx 抛 ApiError
 * - 错误体兼容:HTTP 非 2xx 时后端可能漏信封,按 {code,message} 宽松解析
 */
export async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers)
  if (options.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json')
  }
  const token = getToken()
  if (token && !headers.has('Authorization')) {
    headers.set('Authorization', `Bearer ${token}`)
  }

  const res = await fetch(API_BASE + path, { ...options, headers })

  // 不管 HTTP 状态码,先读信封。
  // 后端把 1401「未登录」返成 HTTP 400 + envelope {code:1401},得看 envelope 不只看状态码。
  const env = (await res.json().catch(() => ({}))) as Partial<ApiEnvelope<T>>
  const code = env.code ?? 'INTERNAL'
  const message = env.message ?? `HTTP ${res.status}`

  // 全局鉴权失效:任何 1401 都触发(不管 HTTP 是 200 / 400 / 401)
  if (code === 1401) {
    notifyAuthInvalid()
  }

  if (!res.ok || code !== 0) {
    throw new ApiError(code as number | string, message, res.status)
  }
  return env.data as T
}
