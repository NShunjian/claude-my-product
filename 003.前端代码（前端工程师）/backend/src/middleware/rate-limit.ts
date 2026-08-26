import rateLimit from 'express-rate-limit'
import { AppError, ErrorCode } from '../constants/errors.js'
import { env } from '../config/env.js'

export const authLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: env.RATE_LIMIT_MAX, // 10 req/min in production; overridden to 10000 in tests
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req, _res, next) => {
    next(new AppError(429, ErrorCode.RATE_LIMIT, '请求过于频繁，请稍后再试'))
  },
})
