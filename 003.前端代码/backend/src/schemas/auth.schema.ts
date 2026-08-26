import { z } from 'zod'

const usernameRule = z
  .string()
  .trim()
  .min(2, '用户名至少 2 个字符')
  .max(20, '用户名最多 20 个字符')
  .regex(/^[A-Za-z0-9_一-龥]+$/, '用户名仅限字母/数字/中文/下划线')

const passwordRule = z
  .string()
  .min(6, '密码至少 6 位')
  .max(32, '密码最多 32 位')

export const registerSchema = z.object({
  username: usernameRule,
  password: passwordRule,
})

export const loginSchema = z.object({
  username: z.string().trim().min(1, '用户名不能为空'),
  password: z.string().min(1, '密码不能为空'),
})

export type RegisterInput = z.infer<typeof registerSchema>
export type LoginInput = z.infer<typeof loginSchema>
