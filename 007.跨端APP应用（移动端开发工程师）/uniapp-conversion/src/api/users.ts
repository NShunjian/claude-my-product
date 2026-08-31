import { request } from './http'

export type Gender = 'male' | 'female' | 'other'

export interface UserProfile {
  id: number
  uuid: string
  username: string
  displayName: string | null
  avatar: string | null
  gender: Gender | null
  age: number | null
  createdAt: string
}

export interface UserEnvelope {
  user: UserProfile
}

export interface UpdateProfileInput {
  displayName?: string | null
  avatar?: string | null
  gender?: Gender | null
  age?: number | null
}

export interface ChangePasswordInput {
  oldPassword: string
  newPassword: string
}

export async function updateProfile(input: UpdateProfileInput): Promise<UserProfile> {
  const res = await request<UserEnvelope>('/api/users/me', {
    method: 'PATCH',
    data: input,
  })
  return res.user
}

export async function changePassword(input: ChangePasswordInput): Promise<void> {
  await request<{ ok: true }>('/api/users/me/password', {
    method: 'POST',
    data: input,
  })
}
