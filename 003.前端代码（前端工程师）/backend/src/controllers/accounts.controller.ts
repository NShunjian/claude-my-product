import type { Request, Response, NextFunction } from 'express'
import { createAccountSchema, updateAccountSchema } from '../schemas/accounts.schema.js'
import * as accountsService from '../services/accounts.service.js'

export const list = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const items = await accountsService.listAccounts(userId)
    res.json({ items })
  } catch (e) {
    next(e)
  }
}

export const create = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const input = createAccountSchema.parse(req.body)
    const account = await accountsService.createAccount(userId, input)
    res.status(201).json({ account })
  } catch (e) {
    next(e)
  }
}

export const update = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const id = req.params.id
    const input = updateAccountSchema.parse(req.body)
    const account = await accountsService.updateAccount(userId, id, input)
    res.json({ account })
  } catch (e) {
    next(e)
  }
}

export const remove = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const id = req.params.id
    await accountsService.deleteAccount(userId, id)
    res.status(204).send()
  } catch (e) {
    next(e)
  }
}