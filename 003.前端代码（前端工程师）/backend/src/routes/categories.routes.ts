import { Router } from 'express'
import * as controller from '../controllers/categories.controller.js'

export const categoriesRouter = Router()

categoriesRouter.get('/', controller.list)