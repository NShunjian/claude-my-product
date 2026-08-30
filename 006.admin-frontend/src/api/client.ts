/**
 * 后端 API client —— 单例 fetch wrapper,自动挂 JWT,统一异常形态。
 *
 * 设计:
 *   - base URL 通过 import.meta.env.VITE_API_BASE 配置,默认 http://localhost:4001
 *   - JWT 存 localStorage('admin_token'),无需额外 store
 *   - 401 (未登录/失效) → 清 token + 抛 ApiError(401),由调用方决定跳登录
 *   - 403 (权限不足) → 抛 ApiError(403),前端 PermissionGate 决定是否显示
 *   - 其他非 0 code → 抛 ApiError(code, message),业务自己处理
 */

import type { ApiResponse } from './types'

export class ApiError extends Error {
  constructor(
    public readonly code: number,
    message: string,
    public readonly httpStatus: number,
  ) {
    super(message)
    this.name = 'ApiError'
  }
}

const TOKEN_KEY = 'admin_token'
const DEFAULT_BASE = 'http://localhost:4001'

function getBase(): string {
  return import.meta.env.VITE_API_BASE || DEFAULT_BASE
}

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(token: string | null): void {
  if (token === null) {
    localStorage.removeItem(TOKEN_KEY)
  } else {
    localStorage.setItem(TOKEN_KEY, token)
  }
}

export function clearAuth(): void {
  setToken(null)
}

interface RequestOptions {
  method?: 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE'
  body?: unknown
  query?: Record<string, string | number | boolean | undefined | null>
  signal?: AbortSignal
}

export async function request<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const { method = 'GET', body, query, signal } = opts

  const url = new URL(path, getBase())
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v === undefined || v === null || v === '') continue
      url.searchParams.set(k, String(v))
    }
  }

  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  }
  const token = getToken()
  if (token) {
    headers['Authorization'] = `Bearer ${token}`
  }

  const init: RequestInit = { method, headers, signal }
  if (body !== undefined) {
    init.body = JSON.stringify(body)
  }

  const res = await fetch(url.toString(), init)

  // 401/403/500 等 HTTP 错误 → 后端拦截器已经返 ApiResponse 形态(code 14xx)
  // 但 401/403 拦截器直接写 response,不带 ApiResponse envelope
  if (res.status === 401) {
    clearAuth()
    // 通知 AuthProvider:token 被服务端作废(V12 token_version 不匹配 / 账号禁用 / 角色没了),
    // 让它清 context state + 跳登录页。仅 dispatch 不 navigate —— 跳转由 React 层做,
    // 避免在 api client 里耦合 router。
    window.dispatchEvent(new CustomEvent('admin-auth-expired', {
      detail: { message: '登录已过期,请重新登录' },
    }))
    throw new ApiError(401, '登录已过期', 401)
  }

  let parsed: ApiResponse<T>
  try {
    parsed = await res.json()
  } catch {
    throw new ApiError(res.status, `HTTP ${res.status}: 非 JSON 响应`, res.status)
  }

  if (parsed.code !== 0) {
    throw new ApiError(parsed.code, parsed.message || '后端错误', res.status)
  }

  return parsed.data
}
