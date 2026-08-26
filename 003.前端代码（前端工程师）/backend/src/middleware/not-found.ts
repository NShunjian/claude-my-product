import type { Request, Response } from 'express'
import { AppError, ErrorCode } from '../constants/errors.js'

export const notFoundHandler = (_req: Request, _res: Response, next: (e?: unknown) => void) => {
  next(new AppError(404, ErrorCode.INTERNAL, '路由不存在'))
}
