import { Router } from 'express'
import * as controller from '../controllers/version.controller.js'

export const versionRouter = Router()

versionRouter.get('/', controller.get)