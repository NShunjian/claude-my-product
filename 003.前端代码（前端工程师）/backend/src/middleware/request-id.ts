import type { RequestHandler } from 'express'
import { randomUUID } from 'node:crypto'

/**
 * 给每个请求分配一个 X-Request-Id:优先用上游传的(便于分布式追踪),否则生成 uuid。
 * 挂到 res.locals.requestId,pino-http 也会自动把它写到日志。
 */
export const requestIdMiddleware: RequestHandler = (req, res, next) => {
  const incoming = req.header('x-request-id')
  const id = incoming && incoming.length > 0 && incoming.length <= 128 ? incoming : randomUUID()
  res.locals.requestId = id
  res.setHeader('X-Request-Id', id)
  next()
}
