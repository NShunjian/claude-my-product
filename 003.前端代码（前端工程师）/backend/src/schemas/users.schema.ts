import { z } from 'zod'

export const genderSchema = z.enum(['male', 'female', 'other'])

const AVATAR_MAX_BYTES = 30 * 1024
// 头像允许两种形态：
// 1) https://  URL（外链头像，≤255 字符）
// 2) data:image/(png|jpeg|webp);base64,XXX（前端压缩后的内联头像，解码后 ≤ 30KB）
const dataUrlAvatar = z
  .string()
  .regex(
    /^data:image\/(png|jpeg|webp);base64,/,
    '头像 dataURL 必须是 data:image/(png|jpeg|webp);base64, 开头',
  )
  .refine(
    (s) => {
      const b64 = s.split(',', 2)[1] ?? ''
      try {
        return Buffer.from(b64, 'base64').length <= AVATAR_MAX_BYTES
      } catch {
        return false
      }
    },
    '头像图片不能超过 30KB',
  )

const urlAvatar = z
  .string()
  .url('头像必须是合法 URL')
  .max(255)
  // 拒绝 data: 前缀 — data: 是合法 URL 但我们用 dataUrlAvatar 这条独立分支校验
  .refine((s) => !s.startsWith('data:'), 'dataURL 必须以 data:image/(png|jpeg|webp);base64, 开头，请走 base64 分支')

export const updateProfileSchema = z
  .object({
    displayName: z.string().trim().min(1, '昵称不能为空').max(50).nullable().optional(),
    avatar: z.union([dataUrlAvatar, urlAvatar]).nullable().optional(),
    gender: genderSchema.nullable().optional(),
    age: z.number().int('年龄必须为整数').min(0).max(120).nullable().optional(),
  })
  .refine((p) => Object.keys(p).length > 0, { message: '请至少提供一个要更新的字段' })

export const changePasswordSchema = z.object({
  oldPassword: z.string().min(1, '请输入旧密码'),
  newPassword: z.string().min(6, '新密码至少 6 位').max(32, '新密码最多 32 位'),
})

export type UpdateProfileInput = z.infer<typeof updateProfileSchema>
export type ChangePasswordInput = z.infer<typeof changePasswordSchema>