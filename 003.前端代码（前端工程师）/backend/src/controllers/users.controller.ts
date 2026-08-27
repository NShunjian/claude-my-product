import type { Request, Response, NextFunction } from 'express'
import { updateProfileSchema, changePasswordSchema } from '../schemas/users.schema.js'
import * as usersService from '../services/users.service.js'

export const updateMe = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const input = updateProfileSchema.parse(req.body)
    const profile = await usersService.updateProfile(req.user!.uuid, input)
    res.json({ user: profile })
  } catch (e) {
    next(e)
  }
}

export const changePassword = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const input = changePasswordSchema.parse(req.body)
    await usersService.changePassword(req.user!.uuid, input)
    res.json({ ok: true })
  } catch (e) {
    next(e)
  }
}