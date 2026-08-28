import rateLimit from 'express-rate-limit'
import { AppError, ErrorCode } from '../constants/errors.js'
import { env } from '../config/env.js'

/** 共用 handler：超限时统一抛 AppError(429) */
const tooManyRequests = (_req: unknown, _res: unknown, next: (err?: unknown) => void): void => {
  next(new AppError(429, ErrorCode.RATE_LIMIT, '请求过于频繁，请稍后再试'))
}

/** auth 端点（注册/登录）：严限,防爆破。 */
export const authLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: env.RATE_LIMIT_MAX, // 10 req/min in production; tests override to 10000
  standardHeaders: true,
  legacyHeaders: false,
  handler: tooManyRequests,
})

/**
 * 业务写操作（创建/修改/删除流水、账户、用户资料）：1 分钟 60 次。
 * 防止恶意客户端狂刷写入拖慢服务 / 污染数据库。
 */
export const writeLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: env.WRITE_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: tooManyRequests,
})

/**
 * 业务读操作（列表、报表）：1 分钟 300 次。
 * 防止被恶意爬取聚合数据。
 */
export const readLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: env.READ_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: tooManyRequests,
})

/**
 * 改密码：1 分钟 5 次。比 writeLimiter 更严,防密码爆破。
 */
export const passwordLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: env.PASSWORD_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  handler: tooManyRequests,
})
