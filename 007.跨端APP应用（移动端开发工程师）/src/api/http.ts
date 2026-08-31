const API_BASE: string =
  (import.meta.env.VITE_API_BASE as string | undefined) ?? 'http://192.168.1.100:4001'

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

  if (code === 1401) {
    for (const fn of authInvalidListeners) {
      try { fn() } catch (e) { console.error('[authInvalid]', e) }
    }
  }

  if (res.statusCode < 200 || res.statusCode >= 300 || code !== 0) {
    throw new ApiError(code as number | string, message, res.statusCode)
  }
  return env.data as T
}
