import { z } from 'zod'

const envSchema = z.object({
  PORT: z.coerce.number().int().positive().default(4000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),

  DB_HOST: z.string().min(1),
  DB_PORT: z.coerce.number().int().positive().default(3306),
  DB_USER: z.string().min(1),
  DB_PASSWORD: z.string(),
  DB_NAME: z.string().min(1),

  JWT_SECRET: z.string().min(32, 'JWT_SECRET must be at least 32 bytes'),
  JWT_EXPIRES_IN: z.string().default('7d'),

  CORS_ORIGIN: z.string().url().default('http://localhost:5173'),
  BCRYPT_COST: z.coerce.number().int().min(4).max(15).default(12),

  RATE_LIMIT_MAX: z.coerce.number().int().positive().default(10),
})

export const env = Object.freeze(envSchema.parse(process.env))
export type Env = typeof env
