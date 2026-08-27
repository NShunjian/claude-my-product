import { Router } from 'express'
import * as controller from '../controllers/records.controller.js'
import { requireAuth } from '../middleware/auth.js'

export const recordsRouter = Router()

recordsRouter.use(requireAuth)
recordsRouter.get('/',       controller.list)
recordsRouter.post('/',      controller.create)
recordsRouter.patch('/:id',  controller.update)
recordsRouter.delete('/:id', controller.remove)