import { z } from 'zod'

export const accountTypeSchema = z.enum(['cash', 'debit', 'credit', 'wallet', 'investment', 'other'])

export const createAccountSchema = z.object({
  name: z.string().trim().min(1, '账户名称不能为空').max(20, '账户名称最多 20 字'),
  type: accountTypeSchema,
  icon: z.string().trim().min(1).max(32).default('💳'),
  initialBalance: z.number().nonnegative('初始余额不能为负').default(0),
  currency: z.string().length(3).default('CNY'),
  isDefault: z.boolean().default(false),
  sortOrder: z.number().int().default(0),
  note: z.string().max(255).nullable().optional(),
})

export const updateAccountSchema = z.object({
  name: z.string().trim().min(1).max(20).optional(),
  icon: z.string().trim().min(1).max(32).optional(),
  initialBalance: z.number().nonnegative().optional(),
  isDefault: z.boolean().optional(),
  sortOrder: z.number().int().optional(),
  note: z.string().max(255).nullable().optional(),
})

export type CreateAccountInput = z.infer<typeof createAccountSchema>
export type UpdateAccountInput = z.infer<typeof updateAccountSchema>