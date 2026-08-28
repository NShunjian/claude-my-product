import { Router } from 'express'
import * as controller from '../controllers/categories.controller.js'
import { readLimiter } from '../middleware/rate-limit.js'

export const categoriesRouter = Router()

categoriesRouter.get('/', readLimiter, controller.list)