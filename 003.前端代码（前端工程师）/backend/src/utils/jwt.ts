import jwt from 'jsonwebtoken'
import { env } from '../config/env.js'
import type { JwtPayload } from '../types/index.js'

export const signToken = (payload: JwtPayload): string =>
  jwt.sign(payload, env.JWT_SECRET, {
    algorithm: 'HS256',
    expiresIn: env.JWT_EXPIRES_IN as jwt.SignOptions['expiresIn'],
  })

export const verifyToken = (token: string): JwtPayload => {
  const decoded = jwt.verify(token, env.JWT_SECRET, { algorithms: ['HS256'] })
  if (typeof decoded === 'string') {
    throw new Error('Invalid token payload')
  }
  return {
    sub: Number(decoded.sub),
    uuid: String((decoded as Record<string, unknown>).uuid),
    username: String((decoded as Record<string, unknown>).username),
  }
}
