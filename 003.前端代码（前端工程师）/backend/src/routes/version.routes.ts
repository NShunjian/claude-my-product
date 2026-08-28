import { Router } from 'express'
import * as controller from '../controllers/version.controller.js'
import { readLimiter } from '../middleware/rate-limit.js'

export const versionRouter = Router()

versionRouter.get('/', readLimiter, controller.get)