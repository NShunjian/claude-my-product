# 003 frontend-react-java — tests/ 目录说明

> 新增目录,不动 src/ 现有任何业务代码与测试。
> 与 src/lib/*.test.ts(纯函数单测)并存,vitest.config.ts 中通过 `include` 区分。

## 目录结构

```
tests/
├── README.md                本文件
├── setup.ts                 vitest 全局 setup(MSW + RTL cleanup)
├── integration/             组件 + 路由 + 状态 集成测试
│   ├── auth-flow.test.ts    鉴权流(注册/登录/401 跳登录)
│   └── router-guards.test.ts 路由守卫(ProtectedRoute)
├── contract/                DTO 契约测试(对齐 005 后端)
│   └── api-envelope.test.ts ApiResponse 信封 + DTO 字段
├── e2e/                     Playwright 端到端冒烟(独立运行)
│   └── smoke.spec.ts
└── fixtures/                测试数据 + MSW handler
```

## 与 src/lib/*.test.ts 的关系

| | src/lib/*.test.ts | tests/ |
|---|---|---|
| 环境 | node(纯函数) | jsdom(组件/DOM) |
| 工具 | vitest only | vitest + RTL + MSW |
| 配置 | 已有 `vitest.config.ts` 默认 include | 通过新 include 匹配 `tests/**/*.{test,spec}.{ts,tsx}` |
| 范围 | 纯逻辑(presentation / finance mappers) | 集成 + E2E + 契约 |

## 命令(由 package.json scripts 注入)

```bash
npm run test            # 跑全部(vitest 默认 include 包含 src/lib 与 tests/)
npm run test:unit       # 只跑 src/lib/*.test.ts
npm run test:integration # 只跑 tests/integration/
npm run test:contract   # 只跑 tests/contract/
npm run test:e2e        # 跑 Playwright(独立)
npm run test:report     # 跑全部 + 拷贝 coverage 到 008.项目测试/测试报告/003-frontend-react-java/coverage
```

## 报告输出

- **coverage HTML + lcov**:`tests/coverage/`(本地)+ 同步到
  `../../008.项目测试（测试工程师）/测试报告/003-frontend-react-java/coverage/`
- **E2E HTML**:`tests/playe-report/`(本地)+ 同步到
  `../../008.项目测试（测试工程师）/测试报告/003-frontend-react-java/e2e/`

`test:report` 用 cp/rsync 在 npm script 里做(见 package.json 修改)。

## 当前状态

骨架就位,具体用例待 QA 按 [003-frontend-react-java.md](../../../../008.项目测试（测试工程师）/测试计划/003-frontend-react-java.md) §5 落地。

## 新增依赖(需 `npm install`)

- `@testing-library/react` + `@testing-library/jest-dom`
- `@testing-library/user-event`
- `jsdom`
- `msw`(可选,contract/integration 阶段启用)
- `@playwright/test`(可选,e2e 阶段启用)

依赖已写入 package.json `devDependencies`,运行 `npm install` 即可装上。

## 关键约定

1. **测试账号**遵循 [不准修改已有账号密码] 规则:用 `reacttest1` / `ReactTest@12345`,不复用已有真实账号。
2. **不动 src/**:`vitest.config.ts` 仅 `include` 调整,src 下现有 3 个单测保持原样继续跑。
3. **MSW handler** 复用真实后端响应形状,Java DTO 是契约基线。