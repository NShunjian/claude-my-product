import { Router } from 'express'
import * as controller from '../controllers/users.controller.js'
import { requireAuth } from '../middleware/auth.js'

export const usersRouter = Router()

usersRouter.use(requireAuth)
usersRouter.patch('/me',         controller.updateMe)
usersRouter.post('/me/password', controller.changePassword)