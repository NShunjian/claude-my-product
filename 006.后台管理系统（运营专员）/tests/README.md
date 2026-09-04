# 006 admin-frontend — tests/ 目录说明

> 新增目录,不动 src/ 现有任何业务代码与测试。

## 目录结构

```
006.后台管理系统（运营专员）/
├── src/                        业务代码(不动)
├── tests/
│   ├── README.md               本文件
│   ├── setup.ts                vitest 全局 setup(matchMedia + RTL cleanup)
│   ├── integration/            路由 + 状态 + 数据流 集成测试
│   │   ├── auth-flow.test.ts   鉴权 + ProtectedRoute
│   │   └── api-client.test.ts request<T>() 错误码分发
│   ├── permissions/            17 权限码 × 3 角色 = 51 组合矩阵测试
│   │   └── usePermissions.test.ts
│   ├── e2e/                    Playwright 端到端冒烟(独立运行)
│   │   └── admin.spec.ts
│   ├── fixtures/               MSW handler + 测试数据
│   ├── playwright-report/       本地 playwright 输出(不进 git)
│   ├── playwright.config.ts    Playwright 配置
│   ├── coverage/                本地 coverage 输出(不进 git)
│   └── scripts/
│       └── copy-report.mjs     同步到 008.项目测试/测试报告/006-admin-frontend/
└── vitest.config.ts            vitest 配置(jsdom 环境 + coverage)
```

## 命令

```bash
npm run test                  # 跑全部(vitest include 匹配 tests/)
npm run test:integration      # 只跑 tests/integration/
npm run test:permissions      # 只跑 tests/permissions/
npm run test:e2e              # 跑 Playwright(独立,需后端 + preview)
npm run test:coverage         # 跑全部 + 生成 coverage
npm run test:report           # test:coverage + 拷贝到 008.项目测试/测试报告/006-admin-frontend/
```

## 报告输出

- **vitest coverage**(HTML + lcov):`tests/coverage/` + 同步到
  `../../008.项目测试（测试工程师）/测试报告/006-admin-frontend/coverage/`
- **Playwright E2E**(HTML):`tests/playwright-report/` + 同步到
  `../../008.项目测试（测试工程师）/测试报告/006-admin-frontend/e2e/`

## 当前状态

骨架就位,4 个 spec 文件 + 配置 + copy 脚本 + README。

## 新增依赖(需 `npm install`)

- `@testing-library/react` + `@testing-library/jest-dom` + `@testing-library/user-event`
- `happy-dom`(JSX 渲染环境)
- `msw`(可选,API mock)
- `@playwright/test`(可选,E2E)

依赖已写入 package.json `devDependencies`。

## 关键约定

1. **测试账号**:`admintest_admin` / `AdminTest@12345` + `admintest_viewer` / `AdminTest@12345`,
   `superadmin` 由 `ADMIN_BOOTSTRAP_*` env 触发创建。
2. **不动 src/**:`vitest.config.ts` 仅 `include` 指向新 tests/,不触动 src/。
4. **token 命名空间隔离**:admin 用 `localStorage.admin_token`,与主前端 `qz_token` 不污染。