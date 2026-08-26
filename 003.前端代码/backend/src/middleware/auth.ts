import type { Request, RequestHandler } from 'express'
import { AppError, ErrorCode } from '../constants/errors.js'
import { verifyToken } from '../utils/jwt.js'
import type { JwtPayload } from '../types/index.js'

export const requireAuth: RequestHandler = (req, _res, next) => {
  const header = req.header('authorization')
  if (!header || !header.startsWith('Bearer ')) {
    return next(new AppError(401, ErrorCode.MISSING_TOKEN, '未登录或登录已过期'))
  }
  const token = header.slice('Bearer '.length).trim()
  try {
    const payload: JwtPayload = verifyToken(token)
    ;(req as Request & { user?: JwtPayload }).user = payload
    next()
  } catch {
    next(new AppError(401, ErrorCode.INVALID_TOKEN, 'token 无效或已过期'))
  }
}
