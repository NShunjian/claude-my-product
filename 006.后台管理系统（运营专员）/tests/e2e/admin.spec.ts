/**
 * 006 admin-frontend — Playwright E2E 冒烟(占位骨架)
 *
 * 覆盖目标(按 006-admin-frontend.md §5.5):
 *   1. admin 登录 → Dashboard → 看到 4 KPI
 *   2. 重置密码普通用户 → 该用户被踢回登录(V8 token_version)
 *   3. viewer 角色访问 /audit-logs → 不可达
 *   4. 创建预设分类 → 前端用户列表里能选到
 *   5. 禁用业务用户 → 该用户登录 → 失败
 *   6. 批量删除业务用户 → 确认弹窗 → 列表少 N 条
 *   7. CORS:5174 → 4001 跨域请求带自定义 header → 通过
 *
 * 前置:
 *   - Java 后端 005 :4001 已起 + 至少 3 个 admin 角色账号
 *   - 前端 vite preview 起 dist/ 产物:http://localhost:5174
 *
 * 运行:`npm run test:e2e`  → 报告输出至 tests/playe-report/
 *       然后 test:report:copy 把报告同步到
 *       008.项目测试（测试工程师）/测试报告/006-admin-frontend/e2e/
 *
 * 状态:骨架。Playwright 安装 + 用例落地待 QA 启动。
 */
import { describe, it, expect } from 'vitest'

describe('E2E smoke (skeleton — Playwright)', () => {
  it('placeholder — Playwright not yet wired', () => {
    expect(true).toBe(true)
  })
  // TODO(impl):
  // - import { test, expect } from '@playwright/test'
  // - beforeAll: page.goto('http://localhost:5174')
  // - test 1: login admin → assert /dashboard 显示 4 KPI
  // - test 2: AdminUsers → 重置密码某用户 → 该用户重新登录 → 旧 token 失效
  // - test 3: viewer login → 访问 /audit-logs → 404 或空白
  // - test 4: AdminCategories → 创建分类 → 该分类在普通前端 007 用户列表里可选
  // - test 5: AdminUsers → 禁用某用户 → 该用户重新登录失败 1012
  // - test 6: AdminBusinessUsers → 批量删除 → 确认 → 列表少 N 条
  // - test 7: 跨域 OPTIONS 预检 → 200
})