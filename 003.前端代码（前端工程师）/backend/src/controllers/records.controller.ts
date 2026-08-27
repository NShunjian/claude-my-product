import type { Request, Response, NextFunction } from 'express'
import { createRecordSchema, updateRecordSchema, listRecordsQuerySchema } from '../schemas/records.schema.js'
import * as recordsService from '../services/records.service.js'

export const list = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const query = listRecordsQuerySchema.parse(req.query)
    const items = await recordsService.listRecords(userId, query)
    res.json({ items })
  } catch (e) {
    next(e)
  }
}

export const create = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const input = createRecordSchema.parse(req.body)
    const record = await recordsService.createRecord(userId, input)
    res.status(201).json({ record })
  } catch (e) {
    next(e)
  }
}

export const update = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const id = req.params.id
    const input = updateRecordSchema.parse(req.body)
    const record = await recordsService.updateRecord(userId, id, input)
    res.json({ record })
  } catch (e) {
    next(e)
  }
}

export const remove = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
  try {
    const userId = req.user!.sub
    const id = req.params.id
    await recordsService.deleteRecord(userId, id)
    res.status(204).send()
  } catch (e) {
    next(e)
  }
}