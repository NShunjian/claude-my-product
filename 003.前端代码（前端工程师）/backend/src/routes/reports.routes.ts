import { Router } from 'express'
import * as controller from '../controllers/reports.controller.js'
import { requireAuth } from '../middleware/auth.js'
import { readLimiter } from '../middleware/rate-limit.js'

export const reportsRouter = Router()

reportsRouter.use(requireAuth)
reportsRouter.get('/monthly', readLimiter, controller.monthly)
reportsRouter.get('/yearly',  readLimiter, controller.yearly)