#!/usr/bin/env node
/**
 * 006 admin-frontend — 测试报告拷贝脚本
 *
 * 拷贝源:
 *   tests/coverage/         → 008.../006-admin-frontend/coverage/
 *   tests/playwright-report/ → 008.../006-admin-frontend/e2e/
 *
 * 用法:`npm run test:report:copy` 或 `node tests/scripts/copy-report.mjs 006-admin-frontend`
 */
import { cp, mkdir, stat } from 'node:fs/promises'
import { dirname, resolve, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = resolve(__dirname, '../..')
const repoRoot = resolve(projectRoot, '../..')

const project = process.argv[2]
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
await safeCp(join(projectRoot, 'tests/coverage'), 'coverage')
await safeCp(join(projectRoot, 'tests/playwright-report'), 'e2e')

console.log(`\n[done] reports -> ${dest}`)