/**
 * 007 uniapp-project — Playwright 配置(占位骨架)
 *
 * 范围:H5 平台(http://localhost:5181)+ Chrome desktop 浏览器自动化。
 *       iOS APP-PLUS 与 mp-weixin 走真机,不进 Playwright。
 *
 * 前置:
 *   - Java 后端 005 :4001
 *   - HBuilder/H5 dev 起来:H5 dev server 在 :5181(非默认 5173)
 *
 * 运行:`npm run test:e2e`  → 报告输出至 tests/playwright-report/
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
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:5181',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    // iOS 真机 + Android 真机由 QA 走 tests/platforms/ 清单 + miniprogram-automator
  ],
})