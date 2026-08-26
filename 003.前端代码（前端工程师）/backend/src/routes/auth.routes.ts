import { Router } from 'express'
import * as controller from '../controllers/auth.controller.js'
import { requireAuth } from '../middleware/auth.js'
import { authLimiter } from '../middleware/rate-limit.js'

export const authRouter = Router()

authRouter.post('/register', authLimiter, controller.register)
authRouter.post('/login',    authLimiter, controller.login)
authRouter.get('/me',        requireAuth,  controller.me)
authRouter.post('/logout',   requireAuth,  controller.logout)
