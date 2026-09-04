import { defineConfig } from 'vitest/config'
import { fileURLToPath, URL } from 'node:url'

/**
 * 007 uniapp-project — vitest 配置
 *
 * 挑战:uni-app 用 `<!-- #ifdef H5 || APP-PLUS -->` 等平台条件编译,Node 跑 vitest
 *       时这些条件编译不生效,组件可能引用 `uni.*` / `getApp()` 等不存在 API。
 *       因此本配置只 include 平台无关的纯逻辑测试,平台特定场景留给真机。
 *
 * include:
 *   - tests/unit/**         → 纯函数(utils/finance / category-presentation / nav-intent)
 *   - tests/stores/**       → Pinia 状态机(quick-add 等)
 *
 * exclude:
 *   - tests/platforms/**    → markdown 清单,非测试
 *   - tests/e2e/**          → Playwright,独立运行
 *   - tests/playwright-report/**  → 输出目录
 *
 * 注:不挂 @vitejs/plugin-vue —— 纯逻辑测试用不到 SFC 编译,
 *     且 plugin-vue 5 强制 vue@3 会和 uni-app 的 vue@2 冲突。
 *
 * coverage:
 *   - 本地输出 tests/coverage/(不进 git)
 *   - test:report 脚本再 cp 到 008.项目测试/测试报告/007-uniapp-project/coverage/
 */
export default defineConfig({
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./', import.meta.url)),
    },
  },
  test: {
    include: [
      'tests/unit/**/*.{test,spec}.{ts,tsx}',
      'tests/stores/**/*.{test,spec}.{ts,tsx}',
    ],
    exclude: [
      'tests/platforms/**',
      'tests/e2e/**',
      'tests/playwright-report/**',
    ],
    environment: 'happy-dom',
    setupFiles: ['tests/setup.ts'],
    css: false,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov', 'json-summary'],
      reportsDirectory: './tests/coverage',
      include: [
        'utils/**/*.ts',
        'stores/**/*.ts',
        'api/**/*.ts',
      ],
      exclude: [
        'utils/url-polyfill.ts',
      ],
      thresholds: {
        lines: 50,
        functions: 50,
        branches: 40,
        statements: 50,
      },
    },
  },
})