import { Router } from 'express'
import * as controller from '../controllers/records.controller.js'
import { requireAuth } from '../middleware/auth.js'
import { readLimiter, writeLimiter } from '../middleware/rate-limit.js'

export const recordsRouter = Router()

recordsRouter.use(requireAuth)
recordsRouter.get('/',       readLimiter,  controller.list)
recordsRouter.post('/',      writeLimiter, controller.create)
recordsRouter.patch('/:id',  writeLimiter, controller.update)
recordsRouter.delete('/:id', writeLimiter, controller.remove)