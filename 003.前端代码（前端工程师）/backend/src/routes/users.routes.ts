import { Router } from 'express'
import * as controller from '../controllers/users.controller.js'
import { requireAuth } from '../middleware/auth.js'
import { writeLimiter, passwordLimiter } from '../middleware/rate-limit.js'

export const usersRouter = Router()

usersRouter.use(requireAuth)
usersRouter.patch('/me',         writeLimiter,   controller.updateMe)
usersRouter.post('/me/password', passwordLimiter, controller.changePassword)