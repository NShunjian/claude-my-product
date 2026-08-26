import { createApp } from './app.js'
import { env } from './config/env.js'
import { closePool } from './db/pool.js'

const app = createApp()
const server = app.listen(env.PORT, () => {
  console.log(`[qingzhang-backend] listening on http://localhost:${env.PORT}`)
  console.log(`[qingzhang-backend] env=${env.NODE_ENV} db=${env.DB_NAME}`)
})

const shutdown = async (signal: string) => {
  console.log(`\n[qingzhang-backend] received ${signal}, closing...`)
  server.close(async () => {
    await closePool()
    process.exit(0)
  })
}

process.on('SIGINT', () => void shutdown('SIGINT'))
process.on('SIGTERM', () => void shutdown('SIGTERM'))
