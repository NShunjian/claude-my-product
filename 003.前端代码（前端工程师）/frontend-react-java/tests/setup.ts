/**
 * 003 frontend-react-java — vitest 全局 setup
 *
 * 职责:
 *   - 注入全局 fetch / localStorage polyfill(jsdom 已自带)
 *   - 集成测试中按需启动 MSW(在测试文件里 setupServer)
 *
 * 注意:src/lib/*.test.ts 走的是纯函数路径(node 环境),
 *       tests/ 下的集成/E2E 测试走 jsdom 环境(组件挂载 + 路由)。
 *
 * v2 更新:不再强依赖 @testing-library/react(避免未安装时 setup 失败);
 *         用例中需要 cleanup 时自己 import + 调用。
 */
import { afterEach } from 'vitest'

afterEach(() => {
  // localStorage / fetch mock 由各用例自己 reset,避免用例间串味
  localStorage.clear()
})