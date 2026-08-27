import type { Request, Response, NextFunction } from 'express'
import { monthlyQuerySchema, yearlyQuerySchema } from '../schemas/reports.schema.js'
import * as reportsService from '../services/reports.service.js'

export const monthly = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const { month } = monthlyQuerySchema.parse(req.query)
    const report = await reportsService.getMonthlyReport(userId, month)
    res.json(report)
  } catch (e) {
    next(e)
  }
}

export const yearly = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const { year } = yearlyQuerySchema.parse(req.query)
    const report = await reportsService.getYearlyReport(userId, year)
    res.json(report)
  } catch (e) {
    next(e)
  }
}