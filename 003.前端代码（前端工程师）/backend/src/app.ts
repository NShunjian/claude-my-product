import express, { type Application } from 'express'

export const createApp = (): Application => {
  const app = express()
  app.get('/health', (_req, res) => res.json({ ok: true }))
  return app
}
