/**
 * 006 admin-frontend — Playwright 配置(占位骨架)
 *
 * 前置:
 *   - Java 后端 005 :4001 + admin 三角色测试账号
 *   - 前端 vite preview 起 dist/ 产物:http://localhost:5174
 *
 * 运行:`npm run test:e2e` → 报告输出至 tests/playwright-report/
 */
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['list'],
    ['html', { outputFolder: 'tests/playwright-report', open: 'never' }],
    ['json', { outputFile: 'tests/playwright-report/results.json' }],
  ],
  use: {
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:5174',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
  webServer: process.env.E2E_NO_SERVER
    ? undefined
    : {
        command: 'npm run preview',
        url: 'http://localhost:5174',
        reuseExistingServer: !process.env.CI,
        timeout: 60_000,
      },
})