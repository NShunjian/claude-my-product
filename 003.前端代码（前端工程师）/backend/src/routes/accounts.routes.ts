import { Router } from 'express'
import * as controller from '../controllers/accounts.controller.js'
import { requireAuth } from '../middleware/auth.js'
import { readLimiter, writeLimiter } from '../middleware/rate-limit.js'

export const accountsRouter = Router()

accountsRouter.use(requireAuth)
accountsRouter.get('/',       readLimiter,  controller.list)
accountsRouter.post('/',      writeLimiter, controller.create)
accountsRouter.patch('/:id',  writeLimiter, controller.update)
accountsRouter.delete('/:id', writeLimiter, controller.remove)