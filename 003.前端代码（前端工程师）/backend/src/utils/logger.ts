import pino from 'pino'
import { env } from '../config/env.js'

/**
 * 全局 logger:pino 输出 JSON(生产)/ pretty(dev)。在 req 上下文里用 req.log 携带 requestId。
 */
export const logger = pino({
  level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  ...(env.NODE_ENV === 'development' && {
    transport: { target: 'pino/file', options: { destination: 1 } },
  }),
})
