import type { Request, Response, NextFunction } from 'express'
import * as authService from '../services/auth.service.js'
import type { LoginInput, RegisterInput } from '../schemas/auth.schema.js'

export const register = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = req.body as RegisterInput
    const result = await authService.register(input)
    res.status(201).json(result)
  } catch (e) {
    next(e)
  }
}

export const login = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const input = req.body as LoginInput
    const result = await authService.login(input)
    res.json(result)
  } catch (e) {
    next(e)
  }
}

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
