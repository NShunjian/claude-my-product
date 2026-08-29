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

export interface Credentials {
  username: string
  password: string
}

/** 后端 /api/auth/register|login 的 data 部分。 */
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

/** 后端 /api/auth/me 的 data 部分:User 本身(不再包一层)。 */
export async function me(options?: { signal?: AbortSignal }): Promise<User> {
  return request<User>('/api/auth/me', { method: 'GET', signal: options?.signal })
}

export async function logout(): Promise<{ ok: true }> {
  return request<{ ok: true }>('/api/auth/logout', { method: 'POST' })
}
