#!/usr/bin/env node
/**
 * 把本地 tests/coverage / tests/playwright-report 拷贝到
 * 008.项目测试（测试工程师）/测试报告/<project>/
 *
 * 入参(命令行):
 *   1) project 目录名,如 003-frontend-react-java
 *
 * 路径解析:
 *   本脚本位于 003/005/006/007 任一项目下的 tests/scripts/
 *   拷贝目标:../../../008.项目测试（测试工程师）/测试报告/<project>/
 *   拷贝源:
 *     - ../coverage/  → 目标/coverage/
 *     - ../playwright-report/  → 目标/e2e/
 *     - ../../target/surefire-reports/(005)/  → 目标/surefire/
 *     - tests/smoke/*.log(005)/  → 目标/smoke/
 *
 * 不存在的源跳过(允许只跑部分测试)。
 */
import { cp, mkdir, stat, readdir } from 'node:fs/promises'
import { dirname, resolve, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = resolve(__dirname, '../..') // 项目根
const repoRoot = resolve(projectRoot, '../..') // 仓库根(008 同级)

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

// 通用:vitest coverage
await safeCp(join(projectRoot, 'tests/coverage'), 'coverage')
// 通用:playwright-report
await safeCp(join(projectRoot, 'tests/playwright-report'), 'e2e')

// 005 Java 后端专项
await safeCp(join(projectRoot, 'target/surefire-reports'), 'surefire')
await safeCp(join(projectRoot, 'target/site/jacoco'), 'coverage')
await safeCp(join(projectRoot, 'tests/smoke'), 'smoke')

console.log(`\n[done] reports -> ${dest}`)