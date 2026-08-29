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

  // HTTP 非 2xx —— 后端仍可能返了信封(GlobalExceptionHandler 统一返 ApiResponse),
  // 也可能没返(网关错误 / 401 由前端 filter 截断),宽松解析。
  if (!res.ok) {
    if (res.status === 401) {
      notifyAuthInvalid()
    }
    const body = (await res.json().catch(() => ({}))) as Partial<ApiEnvelope<unknown>>
    const code = body.code ?? 'INTERNAL'
    const message = body.message ?? `HTTP ${res.status}`
    throw new ApiError(code as number | string, message, res.status)
  }

  // HTTP 2xx —— 必须按信封读 data。
  const env = (await res.json()) as ApiEnvelope<T>
  if (env.code !== 0) {
    // 200 但 code!=0:业务流未走 @ExceptionHandler 的场景(理论上不会发生,留兜底)
    throw new ApiError(env.code, env.message, res.status)
  }
  return env.data as T
}
