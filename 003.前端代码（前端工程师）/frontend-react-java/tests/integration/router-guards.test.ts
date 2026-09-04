/**
 * 003 frontend-react-java — 路由守卫 + 数据流集成测试(占位骨架)
 *
 * 覆盖目标(按 003-frontend-react-java.md §5.3):
 *   - ProtectedRoute 未登录 → 重定向 /login
 *   - 登录后访问 /login → 自动跳 /dashboard
 *   - 路由切换不丢全局 store 状态
 *
 * 工具:MemoryRouter + initialEntries 控制入口
 *
 * 状态:骨架。
 */
import { describe, it } from 'vitest'

/**
 * 路由守卫集成测试占位 —— QA Playwright 阶段再补。
 * 当前用 it.skip 占位(避免 CI 报红),详见 README + 003-frontend-react-java.md §5.3。
 */
describe('Router guards (skeleton — pending QA)', () => {
  it.skip('ProtectedRoute 未登录 → /login', () => {})
  it.skip('已登录访问 /login → /dashboard', () => {})
  // TODO(impl):
  // - 渲染 App,MemoryRouter initialEntries=['/dashboard'],localStorage 无 token
  // - 断言 location.pathname === '/login'
  //
  // - 渲染 App,MemoryRouter initialEntries=['/login'],localStorage 有 token
  // - 断言 location.pathname === '/dashboard'
  //
  // - 模拟 user 切换(token_version 失效)→ 401 → 跳 /login
})