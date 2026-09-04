import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

/**
 * 003 frontend-react-java — vitest 配置
 *
 * 双 include 双 environment:
 *   - src/lib/**.{test,spec}.{ts,tsx}   → node 环境,纯函数测试(已有,不动)
 *   - tests/**.{test,spec}.{ts,tsx}     → jsdom 环境,组件/集成/E2E 骨架
 *
 * coverage:
 *   - 本地输出 tests/coverage/(不进 git)
 *   - test:report 脚本再 cp 到 008.项目测试/测试报告/003-frontend-react-java/coverage/
 */
export default defineConfig({
  plugins: [react()],
  test: {
    include: [
      'src/**/*.{test,spec}.{ts,tsx}', // 已有:lib/ 下 3 个单测
      'tests/**/*.{test,spec}.{ts,tsx}', // 新增:集成 + 契约 + e2e 骨架
    ],
    environment: 'node',
    // 按文件单独指定环境(jsdom 文件加 /* @vitest-environment jsdom */ 注释)
    environmentMatchGlobs: [
      ['tests/integration/**', 'jsdom'],
      ['tests/contract/**', 'jsdom'],
    ],
    setupFiles: ['tests/setup.ts'],
    css: false,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html', 'lcov', 'json-summary'],
      reportsDirectory: './tests/coverage',
      include: ['src/**/*.{ts,tsx}'],
      exclude: [
        'src/**/*.test.{ts,tsx}',
        'src/**/*.spec.{ts,tsx}',
        'src/main.tsx',
        'src/**/index.ts',
        'src/**/vite-env.d.ts',
      ],
      thresholds: {
        // 起步阈值,后续按计划迭代提升
        lines: 60,
        functions: 60,
        branches: 50,
        statements: 60,
      },
    },
  },
})