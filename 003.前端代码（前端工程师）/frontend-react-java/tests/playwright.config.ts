/**
 * 003 frontend-react-java — Playwright 配置(占位骨架)
 *
 * 前置:
 *   - Java 后端 005 起在 :4001(profile=test 用 H2 内存库 + Flyway)
 *   - 前端 vite preview 起 dist/ 产物:http://localhost:5173
 *
 * 运行:`npm run test:e2e`  → 报告输出至 tests/playwright-report/
 *       然后 test:report:copy 把报告同步到
 *       008.项目测试（测试工程师）/测试报告/003-frontend-react-java/e2e/
 *
 * 状态:骨架。具体 browser 矩阵 + 用例见 003-frontend-react-java.md §5.5。
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
    baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:5173',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    // 真机矩阵由 QA 引入 BrowserStack,本地默认不开
  ],
  webServer: process.env.E2E_NO_SERVER
    ? undefined
    : {
        command: 'npm run preview',
        url: 'http://localhost:5173',
        reuseExistingServer: !process.env.CI,
        timeout: 60_000,
      },
})