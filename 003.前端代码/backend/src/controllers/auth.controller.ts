import type { Request, Response, NextFunction } from 'express'
import * as authService from '../services/auth.service.js'
import { registerSchema, loginSchema } from '../schemas/auth.schema.js'
import { AppError, ErrorCode } from '../constants/errors.js'
import type { RegisterInput, LoginInput } from '../schemas/auth.schema.js'

const validate = (schema: typeof registerSchema | typeof loginSchema) =>
  (req: Request, _res: Response, next: NextFunction) => {
    const result = schema.safeParse(req.body)
    if (!result.success) {
      throw new AppError(400, ErrorCode.INVALID_INPUT, result.error.errors[0]?.message ?? 'Invalid input')
    }
    req.body = result.data
    next()
  }

export const register = [validate(registerSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = req.body as RegisterInput
    const result = await authService.register(input)
    res.status(201).json(result)
  } catch (e) {
    next(e)
  }
}]

export const login = [validate(loginSchema), async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = req.body as LoginInput
    const result = await authService.login(input)
    res.json(result)
  } catch (e) {
    next(e)
  }
}]

export const me = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const user = req.user!
    const fresh = await authService.getCurrentUser(user.uuid)
    res.json({ user: fresh })
  } catch (e) {
    next(e)
  }
}

export const logout = (_req: Request, res: Response) => {
  res.json({ ok: true })
}
