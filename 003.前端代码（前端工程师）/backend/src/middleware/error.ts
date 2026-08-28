import type { ErrorRequestHandler } from 'express'
import { ZodError } from 'zod'
import { AppError, ErrorCode } from '../constants/errors.js'
import { logger } from '../utils/logger.js'

export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  // zod 校验失败
  if (err instanceof ZodError) {
    res.status(400).json({
      error: {
        code: ErrorCode.INVALID_INPUT,
        message: err.issues[0]?.message ?? '参数校验失败',
      },
    })
    return
  }

  // 自定义业务错误
  if (err instanceof AppError) {
    // 5xx 业务错误才打 error,4xx 是用户输入问题不打
    if (err.status >= 500) {
      logger.error({ err, requestId: res.locals.requestId }, '[app error]')
    }
    res.status(err.status).json({ error: { code: err.code, message: err.message } })
    return
  }

  // 兜底
  logger.error({ err, requestId: res.locals.requestId, url: req.url }, '[unhandled error]')
  res.status(500).json({
    error: { code: ErrorCode.INTERNAL, message: '服务器内部错误' },
  })
}
