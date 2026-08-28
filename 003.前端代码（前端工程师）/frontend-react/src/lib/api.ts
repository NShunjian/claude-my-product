export const API_BASE: string =
  import.meta.env.VITE_API_BASE ?? 'http://localhost:4000'

const TOKEN_KEY = 'qz_token'

/** 获取当前保存的 JWT；调用方一般无需直接使用，request() 会自动注入。 */
export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export class ApiError extends Error {
  code: string
  status: number

  constructor(code: string, message: string, status: number) {
    super(message)
    this.code = code
    this.status = status
    this.name = 'ApiError'
  }
}

/**
 * 401 全局回调:任何 request() 收到 401 时触发。
 * AuthContext 注册并清 token + user,然后 ProtectedRoute 自然把用户踢回 /login。
 * 这样运行期任意接口 token 失效都能统一处理,不必每个调用方各自处理。
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
      // 单个 listener 失败不能阻断其他
      console.error('[authInvalid] listener threw', err)
    }
  }
}

interface ErrorBody {
  error?: {
    code?: string
    message?: string
  }
}

/**
 * 统一 fetch 封装：
 * - 自动从 localStorage 注入 Authorization: Bearer <token>
 * - 自动设置 Content-Type: application/json
 * - 自动解析后端 `{ error: { code, message } }` 错误为 ApiError
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

  if (!res.ok) {
    if (res.status === 401) {
      // token 失效(token 被后端拉黑 / 过期) → 全局通知,AuthContext 会清状态并跳登录
      notifyAuthInvalid()
    }
    const body = (await res.json().catch(() => ({}))) as ErrorBody
    const code = body.error?.code ?? 'INTERNAL'
    const message = body.error?.message ?? `HTTP ${res.status}`
    throw new ApiError(code, message, res.status)
  }

  return (await res.json()) as T
}
