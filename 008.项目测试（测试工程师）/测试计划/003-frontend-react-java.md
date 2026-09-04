# 测试计划 — 003 frontend-react-java

**项目**:轻账主前端 SPA(React + Vite,对接 Java 后端 :4001)
**端口**:5173
**对接**:Java 后端 `005.后端代码(Java工程师)/`,`VITE_API_BASE` 默认 `http://localhost:4001`
**当前覆盖率**:已有 vitest 单测 3 个文件(`lib/category-presentation.test.ts`、`lib/finance-mappers.test.ts`、`lib/account-presentation.test.ts`),**无集成/E2E**

---

## 1. 技术栈与目录结构

| 项 | 选型 |
|---|---|
| 框架 | React 19.2 + TypeScript 6 (strict) |
| 构建 | Vite 8 + `@vitejs/plugin-react` |
| 样式 | Tailwind v4 (`@tailwindcss/vite`,token 在 `src/index.css` 的 `@theme {}`) |
| 路由 | react-router-dom 7 |
| 状态 | React Context(`auth/AuthContext`、`i18n/LanguageContext`、`lib/book-context`、`layouts/PageTitleContext`),**无 Redux / Zustand** |
| HTTP | `lib/api.ts` 单一 `request<T>()` + `ApiError` + JWT 注入 |
| 导出 | `xlsx`(records Excel 导出) |
| Lint | oxlint |
| 测试 | vitest 4 |

```
src/
├── main.tsx                       入口:AuthProvider + LanguageProvider + BookProvider + BrowserRouter
├── App.tsx                        路由表
├── index.css                      Tailwind v4 + @theme token
├── auth/                          AuthContext + ProtectedRoute
├── components/                    CategoryBadge / CategoryBreakdown / DatePicker / DonutChart /
│                                  ErrorBoundary / LineChart / MonthPicker / RecordModal /
│                                  Sidebar / Toast / TopBar / TransactionRow
├── layouts/                       通用 Layout 组件 + PageTitleContext
├── pages/                         Login / Home / Accounts / AccountAdd / Books / BookMembers /
│                                  Transactions / RecordExpense / RecordIncome /
│                                  ReportMonthly / ReportYearly / Settings / ProfileEdit
├── api/                           accounts / auth / books / categories / records / reports / users / version
├── lib/                           api / book-context / account-presentation / category-presentation /
│                                  finance-mappers / finance-types / export / hooks
├── i18n/                          LanguageContext + dict.ts
├── theme/                         主题相关
├── version/                         版本信息
```

## 2. 启动方式

```bash
cd "003.前端代码（前端工程师）/frontend-react-java"
npm install                # 首次
cp .env.example .env.local # 可选;默认指向 http://localhost:4001
npm run dev                # → http://localhost:5173
npm run build              # 生产构建到 dist/
npm run test               # vitest 单测
```

**前置**:Java 后端必须起在 4001 + MySQL 已 seed。dev server 配 `host:true` 监听所有接口,扫码真机访问需 `VITE_API_BASE=http://<本机IP>:4001`。

## 3. 核心业务模块

| 模块 | 路径 | 关键能力 |
|---|---|---|
| 认证 | `pages/Login.tsx` + `auth/AuthContext.tsx` | 注册/登录/logout/me、JWT localStorage 持久化、`onAuthInvalid` 监听器踢回登录 |
| 首页 | `pages/Home.tsx` | 月份切换、收支概览、最近流水、按分类支出/收入汇总 |
| 流水 | `pages/Transactions.tsx` | 5 维过滤(month/from/to/type/categoryId/accountId)、`bookId` 跨账本 |
| 记账 | `pages/RecordExpense.tsx` / `RecordIncome.tsx` / `RecordModal.tsx` | expense/income/transfer 三型、转账联动账户 |
| 账户 | `pages/Accounts.tsx` + `AccountAdd.tsx` | 余额来自后端视图(`v_account_balance`)、CRUD |
| 账本 | `pages/Books.tsx` + `BookMembers.tsx` | 多账本切换、成员增删 |
| 报表 | `pages/ReportMonthly.tsx` + `ReportYearly.tsx` | 月报/年报聚合、`bookId` 过滤、图表渲染 |
| 我的 | `pages/Settings.tsx` + `ProfileEdit.tsx` | 改昵称/改密码/语言切换/暗色主题 |
| 导出 | `lib/export.ts` | xlsx 导出流水 |

## 4. 高风险功能(优先级 P0)

| # | 风险点 | 失败后果 |
|---|---|---|
| H1 | `request<T>()` 信封解析 / 401 全局监听 | 登录态失效不能跳登录 / 信封错位致前端拿到 `undefined` 崩页 |
| H2 | 账目 CRUD + 转账联动 | 转账余额算错、跨账本归属校验漏 |
| H3 | 报表聚合 + 月份/年份边界 | 跨年月份、缺失日补 0、bookId 过滤 |
| H4 | 账户余额视图实时计算 | 视图冗余/缓存不一致致首页总额对不上 |
| H5 | 暗色主题 + `prefers-color-scheme` + token 一致 | 颜色不一致 / 表单元素空白 |
| H6 | i18n dict 缺 key 兜底 | 渲染 `[object Object]` 或空白 |
| H7 | 多账本切换上下文 | `book-context` 切换时旧数据残留 |

## 5. 分层测试方案

### 5.1 单元测试(已部分覆盖)
**工具**:vitest
**重点**:
- ✅ 已覆盖:`category-presentation`、`finance-mappers`、`account-presentation`
- ❌ 缺:**纯函数**如 `lib/hooks.ts`、`lib/finance-types`、`lib/export.ts`(xlsx 生成纯函数可抽出)
- ❌ 缺:**Hooks 行为**:用 `@testing-library/react` 测 `useLanguage`、`useAuth`
- ❌ 缺:**错误码映射**:把后端 `code !== 0` 映射到 i18n 文案

**目标覆盖率**:lib/ 目录下 ≥ 80%,i18n/dict.ts 全 key 列表型断言(防漏 key)

### 5.2 组件测试(vitest + @testing-library/react)
**工具**:vitest + `@testing-library/react` + `happy-dom` 或 `jsdom`
**覆盖目标**:
- 13 个 page × 关键路径(挂载/输入/提交/失败吐司)
- 13 个 component × props 边界 + loading/error/empty 三态
- `ErrorBoundary` 触发、错误回退 UI 渲染

**重点组件**:
- `RecordModal`:打开/关闭/确认/取消 + ESC + mask 点击关闭
- `TransactionRow`:record 缺字段降级(代码注释明确允许 `record` 字段缺失)
- `DonutChart` / `LineChart`:数据空/单点/超长序列
- `MonthPicker`:跨年、闰年、二月
- `Toast`:堆积、TTL 自动消失

### 5.3 集成测试(MSW + RTL)
**工具**:`msw`(Mock Service Worker)拦截 `fetch`,模拟后端 envelope
**覆盖**:
- 路由跳转 + 数据流全路径:`/login` → `/dashboard` → `/records/:id` → 提交 → 跳回
- `ProtectedRoute` 未登录重定向
- 401 触发 `onAuthInvalid` → 清 token → 跳 `/login`
- 403/网络错误 → 错误吐司 + 保留旧 UI

### 5.4 接口契约测试(对齐 Java 后端)
**工具**:vitest + 自定义 envelope matcher
**目标**:每个 `src/api/*.ts` 函数都对应一组「请求-响应」断言,DTO 字段严格对齐 Java `RecordResponse` / `AccountResponse` / `MonthlyReportResponse`
**测试文件**:`src/api/*.contract.test.ts`(对照 `005.java-backend` 文档)
**关键点**:`Record.amount` 是 number 还是 string(BigDecimal ↔ JSON 序列化)?`Account.balance` 是否在 list 接口携带?

### 5.5 E2E 冒烟(Playwright)
**工具**:`@playwright/test`(`npm i -D`,新依赖 — 评审后引入)
**用例**(优先级):
1. 注册 → 自动跳 `/` → 看到空首页
2. 创建账户 + 类别 expense → 首页显示余额
4. 切月份看月报:数据为空态 / 有数据态
6. 改密 → 旧 token 失效 → 跳登录
7. 多 tab 切换:刷新/前进后退 不丢登录态(对应后端 1401 压制)

### 5.6 可访问性 / 视觉回归(后续)
- `@axe-core/playwright`:登录/记账表单 a11y
- Playwright `toHaveScreenshot()`:Home/Reports 月报/年报视觉回归

### 5.7 兼容性
- Chrome(最新/最新-1)、Safari 17+、Firefox(最新)
- 移动端 viewport:iPhone SE / iPhone 15 Pro Max / iPad mini / Android Chrome

## 6. 测试环境与数据

- 后端:Java `:4001` + H2 内存库(避开 MySQL 真库)+ Flyway V1~V9 完整迁移
- 前端:`vite preview` 起 `dist/` 跑 E2E,绕开 dev HMR 引入的不可重现
- 账号:测试用 `test1` / `Pass@12345`(待 QA 创建;**不得**复用 `dbtest1`**等已有真实账号密码**)
- Mock 后端优先,**禁止**用线上 MySQL 跑前端 E2E

## 7. 进入/退出准则

**进入下一阶段(测试工程师接管)**:
- [ ] 所有 H1~H7 风险项都已在 §5 中映射到具体测试类型
- [ ] 单元/组件测试可在本地 `npm run test` 一键跑

**测试通过准则**:
- [ ] 单元 + 组件:覆盖率 ≥ 80%,无跳过用例
- [ ] 集成 / 契约:全部 API 100% 覆盖
- [ ] E2E:上述 7 个用例全绿,跨浏览器冒烟绿
- [ ] 视觉回归:无新增 diff

---

## 8. 待澄清/需用户决策

| 问题 | 选项 |
|---|---|
| 1. E2E 框架是否批准引入 Playwright(新依赖,~50MB)? | A. 引入(推荐)B. 用 vitest + jsdom 模拟 E2E(覆盖率有限)C. 不做 E2E,只做单元+组件 |
| 2. 视觉回归是否启用(需装 docker 起 chrome)? | A. 启用 B. 仅 a11y 检查 C. 不做 |
| 3. 是否需要把 3 个已有单测纳入 CI? | A. 加 GitHub Actions B. 本地跑就行 |
| 4. 测试账号 `test1` 用什么?(参考 [不准修改已有账号密码](..) 规则,绝不复用 `dbtest1`) |  |

---

**生成时间**:2026-09-04
**生成方**:Claude (由 008.项目测试 目录工作流触发)
**前置依赖**:阅读 [README.md](../README.md)