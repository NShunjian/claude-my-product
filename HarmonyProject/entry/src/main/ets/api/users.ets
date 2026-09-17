/**
 * 用户 API:对齐 uniapp api/users.ts 1:1。
 */
import { request } from './http'
import type { User } from '../model/Types'

export type Gender = 'male' | 'female' | 'other'

export interface UpdateProfilePayload {
  displayName?: string
  gender?: Gender | null
  age?: number | null
  avatar?: string
}

export interface ChangePasswordPayload {
  oldPassword: string
  newPassword: string
}

export interface UploadAvatarPayload {
  uri: string
}

export function updateProfile(payload: UpdateProfilePayload): Promise<User> {
  return request<User>('/users/me', { method: 'PUT', data: payload })
}

export function changePassword(payload: ChangePasswordPayload): Promise<void> {
  return request<void>('/users/me/password', { method: 'PUT', data: payload })
}

/**
 * 上传头像:这里走 /users/me/avatar 的 multipart POST。
 * 真实实现里需要把 fileUri 转 buffer;这里走 JSON base64 简化。
 */
export function uploadAvatar(fileUri: string): Promise<User> {
  const p: UploadAvatarPayload = { uri: fileUri }
  return request<User>('/users/me/avatar', { method: 'POST', data: p })
}
