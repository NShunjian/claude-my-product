import mysql from 'mysql2/promise'
import { env } from '../config/env.js'

let pool: mysql.Pool | undefined

export const getPool = (): mysql.Pool => {
  if (!pool) {
    pool = mysql.createPool({
      host: env.DB_HOST,
      port: env.DB_PORT,
      user: env.DB_USER,
      password: env.DB_PASSWORD,
      database: env.DB_NAME,
      waitForConnections: true,
      connectionLimit: 10,
      charset: 'utf8mb4_unicode_ci',
      dateStrings: false,
      supportBigNumbers: true,
      bigNumberStrings: false,
    })
  }
  return pool
}

export const closePool = async (): Promise<void> => {
  if (pool) {
    await pool.end()
    pool = undefined
  }
}
