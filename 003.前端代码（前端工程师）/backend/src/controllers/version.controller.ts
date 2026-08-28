import type { Request, Response } from 'express'
import { getVersion } from '../services/version.service.js'

/** GET /api/version — 无需鉴权;返回后端权威版本 */
export const get = (_req: Request, res: Response): void => {
  res.json({ version: getVersion() })
}