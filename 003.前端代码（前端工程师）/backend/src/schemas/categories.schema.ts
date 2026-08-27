import { z } from 'zod'

export const categoryTypeSchema = z.enum(['expense', 'income'])

export const listCategoriesQuerySchema = z.object({
  type: categoryTypeSchema.optional(),
})

export type ListCategoriesQuery = z.infer<typeof listCategoriesQuerySchema>