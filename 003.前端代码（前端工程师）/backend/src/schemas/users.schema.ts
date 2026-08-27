import { z } from 'zod'

export const genderSchema = z.enum(['male', 'female', 'other'])

export const updateProfileSchema = z.object({
  displayName: z.string().trim().min(1, '昵称不能为空').max(50).nullable().optional(),
  avatar: z.string().url('头像必须是合法 URL').max(255).nullable().optional(),
  gender: genderSchema.nullable().optional(),
  age: z.number().int('年龄必须为整数').min(0).max(120).nullable().optional(),
}).refine(
  (p) => Object.keys(p).length > 0,
  { message: '请至少提供一个要更新的字段' },
)

export const changePasswordSchema = z.object({
  oldPassword: z.string().min(1, '请输入旧密码'),
  newPassword: z.string().min(6, '新密码至少 6 位').max(32, '新密码最多 32 位'),
})

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>
export type ChangePasswordInput = z.infer<typeof changePasswordSchema>