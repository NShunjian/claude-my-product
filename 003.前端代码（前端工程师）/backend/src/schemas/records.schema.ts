import { z } from 'zod'

export const recordTypeSchema = z.enum(['expense', 'income', 'transfer'])

export const recordSourceSchema = z.enum(['manual', 'import', 'ocr', 'auto', 'sync'])

const dateStr = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, '日期格式必须为 YYYY-MM-DD')

const baseRecordShape = {
  amount: z.number().positive('金额必须大于 0').max(99_999_999.99, '金额超出范围'),
  note: z.string().max(50, '备注最多 50 字').nullable().optional(),
  recordDate: dateStr,
  clientId: z.string().max(64).nullable().optional(),
}

export const createRecordSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('expense'),
    categoryId: z.string().min(1, '请选择分类'),
    accountId: z.string().min(1, '请选择账户'),
    ...baseRecordShape,
  }),
  z.object({
    type: z.literal('income'),
    categoryId: z.string().min(1, '请选择分类'),
    accountId: z.string().min(1, '请选择账户'),
    ...baseRecordShape,
  }),
  z.object({
    type: z.literal('transfer'),
    accountId: z.string().min(1, '请选择转出账户'),
    toAccountId: z.string().min(1, '请选择转入账户'),
    categoryId: z.null().optional(),
    ...baseRecordShape,
  }),
]).refine(
  (r) => r.type !== 'transfer' || r.accountId !== r.toAccountId,
  { message: '转出和转入账户不能相同', path: ['toAccountId'] },
)

export const updateRecordSchema = z.object({
  categoryId: z.string().min(1).nullable().optional(),
  accountId: z.string().min(1).optional(),
  toAccountId: z.string().min(1).nullable().optional(),
  amount: z.number().positive().optional(),
  note: z.string().max(50).nullable().optional(),
  recordDate: dateStr.optional(),
}).refine(
  (r) => !r.accountId || !r.toAccountId || r.accountId !== r.toAccountId,
  { message: '转出和转入账户不能相同', path: ['toAccountId'] },
)

export const listRecordsQuerySchema = z.object({
  month: z.string().regex(/^\d{4}-\d{2}$/, '月份格式必须为 YYYY-MM').optional(),
  from: dateStr.optional(),
  to: dateStr.optional(),
  type: recordTypeSchema.optional(),
  categoryId: z.string().optional(),
  accountId: z.string().optional(),
}).refine(
  (q) => !!(q.month || (q.from && q.to)) || (!q.month && !q.from && !q.to),
  { message: '请提供 month 或同时提供 from + to', path: ['month'] },
)

export type CreateRecordInput = z.infer<typeof createRecordSchema>
export type UpdateRecordInput = z.infer<typeof updateRecordSchema>
export type ListRecordsQuery = z.infer<typeof listRecordsQuerySchema>