import { describe, it, expect } from 'vitest'
import { AppError, ErrorCode } from '../src/constants/errors.js'

describe('AppError', () => {
  it('carries status, code, and message', () => {
    const e = new AppError(401, ErrorCode.INVALID_CREDENTIALS, '用户名或密码错误')
    expect(e).toBeInstanceOf(Error)
    expect(e.status).toBe(401)
    expect(e.code).toBe('INVALID_CREDENTIALS')
    expect(e.message).toBe('用户名或密码错误')
  })
})
