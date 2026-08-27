import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import mysql from 'mysql2/promise'
import { env } from '../config/env.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const SQL_PATH = resolve(__dirname, '../db/sql/02_seed_qingzhang.sql')

/**
 * 灌入演示数据：demo 用户 + 14 个系统预设分类 + demo 账户
 * 依赖 schema 已建好（先跑 db:schema）。
 * 多次执行会被 INSERT 语句自身的唯一键约束阻断（重复报错），属预期行为。
 */
export const runSeed = async (): Promise<void> => {
  const sql = await readFile(SQL_PATH, 'utf8')
  console.log(`[seed] reading ${SQL_PATH} (${sql.length} bytes)`)

  const conn = await mysql.createConnection({
    host: env.DB_HOST,
    port: env.DB_PORT,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    database: env.DB_NAME,
    multipleStatements: true,
  })
  try {
    console.log('[seed] executing DML...')
    await conn.query(sql)
    console.log('[seed] ✅ seed applied successfully')
  } finally {
    await conn.end()
  }
}

// 直接 node 运行此文件时触发自动执行
const isMainModule = process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])
if (isMainModule) {
  runSeed().catch((err: unknown) => {
    console.error('[seed] ❌ failed:', err)
    process.exit(1)
  })
}