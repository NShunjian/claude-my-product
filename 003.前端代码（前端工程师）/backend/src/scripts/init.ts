/**
 * 一次性初始化数据库：先 schema 再 seed。
 * 对应 npm script: db:init
 */
import { runSchema } from './schema.js'
import { runSeed } from './seed.js'

const main = async (): Promise<void> => {
  console.log('==> Step 1/2: schema')
  await runSchema()
  console.log('==> Step 2/2: seed')
  await runSeed()
  console.log('==> ✅ database initialized')
}

main().catch((err: unknown) => {
  console.error('[init] ❌ failed:', err)
  process.exit(1)
})