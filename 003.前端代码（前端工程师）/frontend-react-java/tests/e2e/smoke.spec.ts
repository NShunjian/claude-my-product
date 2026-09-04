/**
 * 003 frontend-react-java — Playwright E2E 冒烟(占位骨架)
 *
 * 覆盖目标(按 003-frontend-react-java.md §5.5):
 *   1. 注册 → 自动跳 / 看到空首页
 *   2. 创建账户 + 类别 expense → 首页显示余额
 *   3. 切月份看月报:数据为空态 / 有数据态
 *   4. 改密 → 旧 token 失效 → 跳登录
 *   5. 多 tab 切换:刷新/前进后退不丢登录态
 *
 * 前置:
 *   - 后端 Java :4001 已起(可用 H2 内存库 profile=test)
 *   - 前端 vite preview 起 dist/ 产物:http://localhost:5173
 *
 * 运行:`npm run test:e2e`  → 报告输出至 008.项目测试/测试报告/003-frontend-react-java/e2e/
 *
 * 当前状态:Playwright 用例落地待 QA 启动,这里全部 it.skip 避免 CI 报红。
 *       README + 003-frontend-react-java.md §5.5 有完整用例说明。
 */
import { describe, it } from 'vitest'

describe('E2E smoke (skeleton — Playwright pending QA)', () => {
  it.skip('register fresh user → 自动跳 / 看到空首页', () => {})
  it.skip('create account → 首页显示余额', () => {})
  it.skip('切月份看月报:数据为空态 / 有数据态', () => {})
  it.skip('改密 → 旧 token 失效 → 跳登录', () => {})
  it.skip('多 tab 切换:刷新 / 前进后退不丢登录态', () => {})
})