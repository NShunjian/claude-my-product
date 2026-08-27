import type { Request, Response, NextFunction } from 'express'
import { listCategoriesQuerySchema } from '../schemas/categories.schema.js'
import * as categoriesService from '../services/categories.service.js'

export const list = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const { type } = listCategoriesQuerySchema.parse(req.query)
    const items = await categoriesService.listCategories(type)
    res.json({ items })
  } catch (e) {
    next(e)
  }
}