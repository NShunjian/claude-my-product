import { describe, it, expect, beforeAll } from 'vitest'
import express from 'express'
import request from 'supertest'
import { signToken } from '../src/utils/jwt.js'
import { requireAuth } from '../src/middleware/auth.js'
import { errorHandler } from '../src/middleware/error.js'

const buildApp = () => {
  const app = express()
  app.get('/protected', requireAuth, (req, res) => res.json({ user: req.user }))
  app.use(errorHandler)
  return app
}

describe('requireAuth middleware', () => {
  it('returns 401 when no Authorization header', async () => {
    const res = await request(buildApp()).get('/protected')
    expect(res.status).toBe(401)
    expect(res.body.error.code).toBe('MISSING_TOKEN')
  })

  it('returns 401 for bad token', async () => {
    const res = await request(buildApp()).get('/protected').set('Authorization', 'Bearer not-a-token')
    expect(res.status).toBe(401)
    expect(res.body.error.code).toBe('INVALID_TOKEN')
  })

  it('attaches user on valid token', async () => {
    const token = signToken({ sub: 42, uuid: 'u', username: 'alice' })
    const res = await request(buildApp()).get('/protected').set('Authorization', `Bearer ${token}`)
    expect(res.status).toBe(200)
    expect(res.body.user).toMatchObject({ sub: 42, username: 'alice' })
  })
})
