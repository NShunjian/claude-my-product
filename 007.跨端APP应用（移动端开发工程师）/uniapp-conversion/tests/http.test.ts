import { describe, it, expect, vi, beforeEach } from 'vitest'

// uni.request mock
const mockRequest = vi.fn()
;(globalThis as any).uni = { request: mockRequest, getStorageSync: () => null }

import { request, ApiError, onAuthInvalid } from '@/api/http'

beforeEach(() => { mockRequest.mockReset() })

describe('http.request', () => {
  it('returns data on success envelope {code:0}', async () => {
    mockRequest.mockImplementation(({ success }: any) =>
      success({ statusCode: 200, data: { code: 0, message: 'ok', data: { hello: 'world' } } })
    )
    const r = await request<{ hello: string }>('/api/test')
    expect(r).toEqual({ hello: 'world' })
  })

  it('throws ApiError when code != 0', async () => {
    mockRequest.mockImplementation(({ success }: any) =>
      success({ statusCode: 200, data: { code: 1401, message: '未登录', data: null } })
    )
    await expect(request('/api/test')).rejects.toBeInstanceOf(ApiError)
  })

  it('throws ApiError on HTTP non-2xx', async () => {
    mockRequest.mockImplementation(({ success }: any) =>
      success({ statusCode: 500, data: { code: 99, message: 'boom' } })
    )
    await expect(request('/api/test')).rejects.toMatchObject({ status: 500 })
  })

  it('notifies authInvalid listeners on code 1401', async () => {
    const fn = vi.fn()
    const off = onAuthInvalid(fn)
    mockRequest.mockImplementation(({ success }: any) =>
      success({ statusCode: 200, data: { code: 1401, message: '未登录' } })
    )
    await request('/api/test').catch(() => {})
    expect(fn).toHaveBeenCalledOnce()
    off()
  })

  it('injects Authorization header when token in storage', async () => {
    ;(globalThis as any).uni.getStorageSync = () => 'tok123'
    mockRequest.mockImplementation(({ success, header }: any) => {
      expect(header.Authorization).toBe('Bearer tok123')
      success({ statusCode: 200, data: { code: 0, message: 'ok' } })
    })
    await request('/api/test')
    ;(globalThis as any).uni.getStorageSync = () => null
  })
})
