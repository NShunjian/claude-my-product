import rateLimit from 'express-rate-limit'
import { AppError, ErrorCode } from '../constants/errors.js'

export const authLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 10,             // 10 requests per IP per minute
  standardHeaders: true,
  legacyHeaders: false,
  handler: (_req, _res, next) => {
    next(new AppError(429, ErrorCode.RATE_LIMIT, '请求过于频繁，请稍后再试'))
  },
})
