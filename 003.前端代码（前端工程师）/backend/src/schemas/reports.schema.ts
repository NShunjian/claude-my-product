import { z } from 'zod'

export const monthlyQuerySchema = z.object({
  month: z.string().regex(/^\d{4}-\d{2}$/, '月份格式必须为 YYYY-MM'),
})

export const yearlyQuerySchema = z.object({
  year: z.coerce.number().int().min(2000).max(2100),
})

export type MonthlyQuery = z.infer<typeof monthlyQuerySchema>
export type YearlyQuery = z.infer<typeof yearlyQuerySchema>