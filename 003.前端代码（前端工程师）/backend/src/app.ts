import express, { type Application } from 'express'
import helmet from 'helmet'
import cors from 'cors'
import { env } from './config/env.js'
import { authRouter } from './routes/auth.routes.js'
import { errorHandler } from './middleware/error.js'
import { notFoundHandler } from './middleware/not-found.js'

export const createApp = (): Application => {
  const app = express()
  app.use(helmet())
  app.use(cors({ origin: env.CORS_ORIGIN, credentials: true }))
  app.use(express.json({ limit: '64kb' }))

  app.get('/health', (_req, res) => res.json({ ok: true }))
  app.use('/api/auth', authRouter)

  app.use(notFoundHandler)
  app.use(errorHandler)
  return app
}
