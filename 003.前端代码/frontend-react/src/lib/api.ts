export const API_BASE: string =
  import.meta.env.VITE_API_BASE ?? 'http://localhost:4000'

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

interface ErrorBody {
  error?: {
    code?: string
    message?: string
  }
}

export async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers)
  if (options.body && !headers.has('Content-Type')) {
    headers.set('Content-Type', 'application/json')
  }

  const res = await fetch(API_BASE + path, { ...options, headers })

  if (!res.ok) {
    const body = (await res.json().catch(() => ({}))) as ErrorBody
    const code = body.error?.code ?? 'INTERNAL'
    const message = body.error?.message ?? `HTTP ${res.status}`
    throw new ApiError(code, message, res.status)
  }

  return (await res.json()) as T
}