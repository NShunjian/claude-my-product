import { readFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { dirname, resolve } from 'node:path'
import mysql from 'mysql2/promise'
import { env } from '../config/env.js'

const __dirname = dirname(fileURLToPath(import.meta.url))
const SQL_PATH = resolve(__dirname, '../db/sql/01_schema_qingzhang.sql')

/**
 * 重置数据库结构：先 drop 所有表/视图，再重建。
 * - 不连 DB_NAME（避免当前数据库不存在时失败），先用 mysql.createConnection 临时连接
 * - 开启 multipleStatements，因为 SQL 含多个 DDL
 */
export const runSchema = async (): Promise<void> => {
  const sql = await readFile(SQL_PATH, 'utf8')
  console.log(`[schema] reading ${SQL_PATH} (${sql.length} bytes)`)

  // 先连到 MySQL 服务（不指定库），确保目标数据库存在
  const bootstrap = await mysql.createConnection({
    host: env.DB_HOST,
    port: env.DB_PORT,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    multipleStatements: true,
  })
  try {
    await bootstrap.query(
      `CREATE DATABASE IF NOT EXISTS \`${env.DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`,
    )
    console.log(`[schema] ensured database '${env.DB_NAME}'`)
  } finally {
    await bootstrap.end()
  }

  // 切到目标库执行 DDL
  const conn = await mysql.createConnection({
    host: env.DB_HOST,
    port: env.DB_PORT,
    user: env.DB_USER,
    password: env.DB_PASSWORD,
    database: env.DB_NAME,
    multipleStatements: true,
  })
  try {
    console.log('[schema] executing DDL...')
    await conn.query(sql)
    console.log('[schema] ✅ schema applied successfully')
  } finally {
    await conn.end()
  }
}

// 直接 node 运行此文件时触发自动执行
const isMainModule = process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])
if (isMainModule) {
  runSchema().catch((err: unknown) => {
    console.error('[schema] ❌ failed:', err)
    process.exit(1)
  })
}