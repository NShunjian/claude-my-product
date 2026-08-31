import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockStorage: Record<string, any> = {}
;(globalThis as any).uni = {
  request: vi.fn(),
  getStorageSync: (k: string) => mockStorage[k] ?? null,
  setStorageSync: (k: string, v: any) => { mockStorage[k] = v },
  removeStorageSync: (k: string) => { delete mockStorage[k] },
  reLaunch: vi.fn(),
}

import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '@/stores/auth'

beforeEach(() => { setActivePinia(createPinia()); for (const k of Object.keys(mockStorage)) delete mockStorage[k] })

describe('auth store', () => {
  it('login stores token + user', async () => {
    ;(uni.request as any).mockImplementation(({ success }: any) =>
      success({ statusCode: 200, data: { code: 0, data: { token: 'T', user: { uuid: 'u1', username: 'alice', displayName: null, avatar: null, gender: null, age: null } } } })
    )
    const auth = useAuthStore()
    await auth.login({ username: 'a', password: 'b' })
    expect(auth.token).toBe('T')
    expect(auth.user?.username).toBe('alice')
    expect(mockStorage.qz_token).toBe('T')
  })

  it('onInvalid clears token + user + reLaunch', () => {
    const auth = useAuthStore()
    auth.token = 'stale'
    auth.user = { uuid: 'u', username: 'x', displayName: null, avatar: null, gender: null, age: null }
    auth.onInvalid()
    expect(auth.token).toBeNull()
    expect(auth.user).toBeNull()
    expect(mockStorage.qz_token).toBeUndefined()
    expect((uni.reLaunch as any)).toHaveBeenCalled()
  })
})
