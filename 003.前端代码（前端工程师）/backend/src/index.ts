import { createApp } from './app.js'
import { env } from './config/env.js'
import { closePool } from './db/pool.js'
import { logger } from './utils/logger.js'

const app = createApp()
const server = app.listen(env.PORT, () => {
  logger.info({ port: env.PORT, env: env.NODE_ENV, db: env.DB_NAME }, 'qingzhang-backend listening')
})

const shutdown = async (signal: string): Promise<void> => {
  logger.info({ signal }, 'received signal, closing')
  server.close(async () => {
    await closePool()
    process.exit(0)
  })
}

process.on('SIGINT', () => void shutdown('SIGINT'))
process.on('SIGTERM', () => void shutdown('SIGTERM'))
