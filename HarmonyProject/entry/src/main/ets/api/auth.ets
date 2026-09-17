/**
 * 认证 API:对齐 uniapp api/auth.ts 1:1。
 */
import { request } from './http'
import type { AuthLoginPayload, AuthRegisterPayload, AuthMeResponse, User } from '../model/Types'

export function register(payload: AuthRegisterPayload): Promise<User> {
  return request<User>('/auth/register', { method: 'POST', data: payload })
}

export function login(payload: AuthLoginPayload): Promise<AuthMeResponse> {
  return request<AuthMeResponse>('/auth/login', { method: 'POST', data: payload })
}

export function me(): Promise<User> { return request<User>('/auth/me') }

export function logout(): Promise<void> { return request<void>('/auth/logout', { method: 'POST' }) }
