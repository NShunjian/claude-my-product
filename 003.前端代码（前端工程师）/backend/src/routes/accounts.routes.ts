import { Router } from 'express'
import * as controller from '../controllers/accounts.controller.js'
import { requireAuth } from '../middleware/auth.js'

export const accountsRouter = Router()

accountsRouter.use(requireAuth)
accountsRouter.get('/',    controller.list)
accountsRouter.post('/',   controller.create)
accountsRouter.patch('/:id',  controller.update)
accountsRouter.delete('/:id', controller.remove)