#!/usr/bin/env node
/**
 * 005 Java 后端 — 测试报告拷贝脚本
 *
 * 拷贝源:
 *   target/surefire-reports/        → 008.../005-java-backend/surefire/
 *   target/site/jacoco/             → 008.../005-java-backend/coverage/
 *   tests/smoke/*.log               → 008.../005-java-backend/smoke/
 *
 * 运行:`npm run test:report:copy` 005-java-backend  (Java 项目借用 Node 脚本便于统一)
 *     或 `./tests/scripts/copy-report.mjs 005-java-backend` 直接 node
 */
import { cp, mkdir, stat } from 'node:fs/promises'
import { dirname, resolve, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = resolve(__dirname, '../..') // 005 项目根
const repoRoot = resolve(projectRoot, '../..') // 仓库根(008 同级)

const project = process.argv[2] ?? '505-java-backend'.replace(/^5/, '0')
if (!project) {
  console.error('usage: copy-report.mjs <project-dir-name>')
  process.exit(1)
}

const dest = join(
  repoRoot,
  '008.项目测试（测试工程师）',
  '测试报告',
  project,
)

async function safeCp(src, dstName) {
  try {
    await stat(src)
  } catch {
    console.log(`[skip] ${src} (not found)`)
    return
  }
  const dst = join(dest, dstName)
  await mkdir(dst, { recursive: true })
  await cp(src, dst, { recursive: true })
  console.log(`[ok]   ${src} -> ${dst}`)
}

await mkdir(dest, { recursive: true })

await safeCp(join(projectRoot, 'target/surefire-reports'), 'surefire')
await safeCp(join(projectRoot, 'target/site/jacoco'), 'coverage')
await safeCp(join(projectRoot, 'tests/smoke'), 'smoke')

console.log(`\n[done] reports -> ${dest}`)