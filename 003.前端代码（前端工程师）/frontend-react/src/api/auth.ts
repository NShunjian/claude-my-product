import { request } from '../lib/api'

export type Gender = 'male' | 'female' | 'other'

export interface User {
  id: number
  uuid: string
  username: string
  displayName: string | null
  avatar: string | null
  gender: Gender | null
  age: number | null
  createdAt: string
}

export interface AuthResponse {
  user: User
  token: string
}

export interface MeResponse {
  user: User
}

export interface Credentials {
  username: string
  password: string
}

export async function register(input: Credentials): Promise<AuthResponse> {
  return request<AuthResponse>('/api/auth/register', {
    method: 'POST',
    body: JSON.stringify(input),
  })
}

export async function login(input: Credentials): Promise<AuthResponse> {
  return request<AuthResponse>('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify(input),
  })
}

/** 需要鉴权；token 由 request() 自动从 localStorage 注入。 */
export async function me(): Promise<MeResponse> {
  return request<MeResponse>('/api/auth/me', { method: 'GET' })
}

/** 调后端 /logout；JWT 无状态，主要给前端一个确认点。 */
export async function logout(): Promise<void> {
  await request<{ ok: true }>('/api/auth/logout', { method: 'POST' })
}