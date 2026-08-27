import { Router } from 'express'
import * as controller from '../controllers/reports.controller.js'
import { requireAuth } from '../middleware/auth.js'

export const reportsRouter = Router()

reportsRouter.use(requireAuth)
reportsRouter.get('/monthly', controller.monthly)
reportsRouter.get('/yearly',  controller.yearly)