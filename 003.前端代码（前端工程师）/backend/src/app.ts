import express, { type Application } from 'express'
import helmet from 'helmet'
import cors from 'cors'
import { env } from './config/env.js'
import { authRouter } from './routes/auth.routes.js'
import { categoriesRouter } from './routes/categories.routes.js'
import { accountsRouter } from './routes/accounts.routes.js'
import { recordsRouter } from './routes/records.routes.js'
import { reportsRouter } from './routes/reports.routes.js'
import { usersRouter } from './routes/users.routes.js'
import { versionRouter } from './routes/version.routes.js'
import { errorHandler } from './middleware/error.js'
import { notFoundHandler } from './middleware/not-found.js'

export const createApp = (): Application => {
  const app = express()
  app.use(helmet())
  app.use(cors({ origin: env.CORS_ORIGIN, credentials: true }))
  app.use(express.json({ limit: '128kb' })) // 64→128: 给 base64 头像留余地（30KB 图 ≈ 40KB base64 + JSON 包装）

  app.get('/health', (_req, res) => res.json({ ok: true }))
  app.use('/api/auth', authRouter)
  app.use('/api/categories', categoriesRouter)
  app.use('/api/accounts', accountsRouter)
  app.use('/api/records', recordsRouter)
  app.use('/api/reports', reportsRouter)
  app.use('/api/users', usersRouter)
  app.use('/api/version', versionRouter)

  app.use(notFoundHandler)
  app.use(errorHandler)
  return app
}
