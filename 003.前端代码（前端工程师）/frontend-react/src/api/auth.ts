import { request } from '../lib/api'

export interface User {
  id: number
  uuid: string
  username: string
  displayName: string | null
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

export async function me(token: string): Promise<MeResponse> {
  return request<MeResponse>('/api/auth/me', {
    method: 'GET',
    headers: { Authorization: `Bearer ${token}` },
  })
}