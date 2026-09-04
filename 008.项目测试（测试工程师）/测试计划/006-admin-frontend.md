# 测试计划 — 006 后台管理系统

**项目**:轻账 Admin 后台 SPA(独立 Vite 工程,运营/客服用)
**端口**:5174
**对接**:Java 后端 `:4001` 的 `/api/admin/**`(经 V5 RBAC,V8 token_version 校验)
**当前覆盖率**:**0**(`src/` 下无 `*.test.*` 文件)

---

## 1. 技术栈与目录结构

| 项 | 选型 |
|---|---|
| 框架 | React 19.2 + TypeScript 6 (strict) |
| 构建 | Vite 8 + Tailwind v4 |
| 路由 | react-router-dom 7(嵌套路由 + `<Outlet/>`) |
| 状态 | React Context(`AdminAuthContext`)+ `usePermissions` hook |
| HTTP | `api/client.ts`:`request<T>()` + `ApiError` + JWT `localStorage.admin_token` |
| Lint | oxlint |
| 测试 | vitest 4(`package.json` 有 `test` script 但无测试文件) |

```
src/
├── main.tsx                  入口
├── App.tsx                   路由表 + Providers(AdminAuthProvider / ToastProvider / ConfirmProvider)
├── index.css                 @tailwindcss + @theme token
├── auth/
│   ├── AdminAuthContext.tsx  user / permissions / roleCodes / isSuperAdmin
│   └── usePermissions.ts     has(code) / hasAny(codes[]) / isSuperAdmin
├── api/
│   ├── client.ts             request<T>() + ApiError + token 持久化
│   └── types.ts              后端 DTO 一一对应的 TS 接口
├── components/
│   ├── ConfirmDialog.tsx     confirm({title, body, danger?}) → Promise<boolean>
│   ├── DataTable.tsx         通用表格 + 分页 + 加载/空态
│   ├── KpiCard.tsx           Dashboard 数字卡片
│   ├── PermissionGate.tsx    <PermissionGate code="...">...</PermissionGate>
│   ├── ProtectedRoute.tsx    未登录跳 /login
│   └── Toast.tsx             toast.success/error/info(msg)
├── layouts/
│   └── AdminLayout.tsx       sidebar + header + <Outlet/>
└── pages/
    ├── AdminLogin.tsx
    ├── AdminDashboard.tsx
    ├── AdminUsers.tsx
    ├── AdminBusinessUsers.tsx  ← 注意:额外页(运营/客服)
    ├── AdminCategories.tsx     预设分类管理
    ├── AdminBooks.tsx          账本审计
    ├── AdminRecords.tsx        流水审计
    └── AdminAuditLogs.tsx      super_admin 专属
```

## 2. 启动方式

```bash
cd "006.后台管理系统（运营专员）"
npm install
cp .env.example .env.local        # VITE_API_BASE=http://localhost:4001
npm run dev                        # → http://localhost:5174

# 或一键
./start-admin
./start-admin status
./start-admin stop
```

**前置**:Java 后端必须起在 4001 + 至少一个 admin 角色用户(默认 `admin/admin123`,由 `admin-smoke.sh` 验证;生产用 `ADMIN_BOOTSTRAP_USERNAME`/`PASSWORD` env 触发 `AdminBootstrapService` 创建 super_admin)。

## 3. 核心业务模块

| 模块 | 路径 | 关键能力 |
|---|---|---|
| 登录 | `pages/AdminLogin.tsx` | `/api/auth/login` → token + user + permissions + roleCodes + isSuperAdmin |
| Dashboard | `AdminDashboard.tsx` | KPI 卡片(用户数/账本数/流水数/分类数) |
| 用户管理 | `AdminUsers.tsx` | 列表、详情、禁用/启用、重置密码、角色授予/撤销 |
| 业务用户 | `AdminBusinessUsers.tsx` | 批量删除(运营专项) |
| 预设分类 | `AdminCategories.tsx` | CRUD + 启停 |
| 账本审计 | `AdminBooks.tsx` | 列表 + 过滤(owner / type / search) + 分页 |
| 流水审计 | `AdminRecords.tsx` | 跨用户流水检索 |
| 审计日志 | `AdminAuditLogs.tsx` | super_admin 专属 |

**核心抽象**:
- `usePermissions().has(code)` / `hasAny(codes)` — super_admin 永远 true(短路)
- `<PermissionGate code="...">` — 包裹 UI
- `<ProtectedRoute>` — 未登录跳登录 + 已登录访问 `/login` 跳 `/dashboard`
- `request<T>()` 自动 401 → 清 token + dispatch `admin-auth-expired` 事件 + 抛 ApiError

## 4. 高风险功能(优先级 P0)

| # | 风险点 | 失败后果 |
|---|---|---|
| H1 | **`adminAuthInterceptor` 5 链**(JWT iat 24h / token_version / admin 角色 / @RequiresPermission) | 权限绕过或失效 |
| H2 | **`usePermissions().has` super_admin 短路** | super_admin 漏显示关键按钮 |
| H3 | **重置密码 / 角色变更**前端确认流程 | 误操作不可逆 |
| H4 | **批量删除业务用户**(新页面 `AdminBusinessUsers`) | 误删不可恢复 |
| H5 | **审计日志查询分页 + 详情** | 数据加载失败/丢失过滤条件 |
| H6 | **CORS + token 命名空间**(主前端 `qz_token` vs admin `admin_token`) | 互相污染 |
| H7 | **ProtectedRoute 边缘**:已登录访问 `/login`、token 失效、401 派发事件 | 循环跳登录 / 永远不跳 |
| H8 | **DataTable 渲染大数据** | 卡顿或越界 |
| H9 | **预设分类启停影响前端** | 用户登录后看到已停用分类 → 提交失败 |
| H10 | **搜索过滤 + URL 状态**(目前只 component state,v2 才接 query params) | 刷新丢失过滤 |

## 5. 分层测试方案

### 5.1 单元测试(vitest)
**覆盖目标**:
- `usePermissions.has()` / `hasAny()` / `isSuperAdmin` 全部路径
- `request<T>()` 错误码分发(401 → dispatch + 清 token,403 → ApiError(403),其他 → ApiError(code))
- `AdminAuthContext` 状态机(initial / loading / authenticated / expired)
- `confirm({danger: true})` Promise resolve/reject
- `toast.success/error/info` 队列、TTL

**目标**:hooks / contexts / pure utils 覆盖率 ≥ 80%

### 5.2 组件测试(@testing-library/react)
**覆盖目标**(7 个 page):
- AdminLogin:提交/错误吐司/loading/disabled
- AdminDashboard:KPI 加载成功/失败
- AdminUsers:列表加载 + 操作(禁用 / 重置密码 / 角色授予)+ ConfirmDialog
- AdminCategories:CRUD 全套 + 启停状态切换
- AdminBooks:过滤输入 + 分页切换
- AdminRecords:同 AdminBooks
- AdminAuditLogs:super_admin 可见 / 非 super_admin 不可见

**重点组件**:
- `<PermissionGate code="user:disable">` 在 `admin` 角色 / `viewer` 角色下表现
- `<ProtectedRoute>` 4 种状态(loading / authenticated / unauthenticated / expired)
- `<DataTable>` loading / empty / data 三态
- `<ConfirmDialog>` danger / 普通 / cancel

### 5.3 集成测试(MSW + RTL)
**工具**:MSW 拦截 `/api/admin/*`,模拟 401 / 403 / 200 / 错误 envelope
**覆盖**:
- 路由跳转:`/login` → `/dashboard` → `/users/{id}` → 操作 → toast → 列表更新
- 401 派发 `admin-auth-expired` 事件 → context 清态 → 跳 `/login`
- 403 派发 ApiError → PermissionGate 隐藏按钮 → 列表操作正常
- 重置密码流程:ConfirmDialog 确认 → API → 列表显示新状态
- 批量删除:多选 → 确认 → API → 列表减项

### 5.4 接口契约测试
**目的**:DTO 严格对齐 Java 后端 DTO
**对照**:见 `005-java-backend.md` §5.4(共享契约)
**重点**:
- `Page<T>` 分页 shape
- `AdminUserListItem` / `AdminCategoryListItem` / `AdminBookListItem` / `AdminRecordListItem` / `AdminAuditLogListItem`
- `AdminMeResponse.permissions: string[]` 与后端 List\<String\> 序列化一致

### 5.5 E2E(Playwright)
**前置**:`admin-smoke.sh` 已通过的 backend(冒烟)
**用例**(优先级):
1. admin 登录 → Dashboard → 看到 4 KPI
2. 重置密码普通用户 → 该用户被踢回登录(V8 token_version)
3. viewer 角色访问 `/audit-logs` → 404 或空白(V12 不可达)
4. 创建预设分类 → 前端用户列表里能选到
5. 禁用业务用户 → 该用户登录 → 失败
6. 批量删除业务用户 → 确认弹窗 → 列表少 N 条
7. CORS:5174 → 4001 跨域请求带自定义 header → 通过

### 5.6 权限矩阵全覆盖测试
**目的**:17 个权限码 × 3 个角色 = 51 个矩阵组合,确保前端按钮可见性 ≠ 后端访问性

| 权限 | super_admin | admin | viewer |
|---|:---:|:---:|:---:|
| `user:list` | ✓ | ✓ | ✓ |
| `user:disable` | ✓ | ✓ | — |
| `user:reset_password` | ✓ | ✓ | — |
| `user:grant_role` | ✓ | — | — |
| `category:preset:create` | ✓ | ✓ | — |
| `category:preset:delete` | ✓ | — | — |
| `audit:list` | ✓ | — | — |
| `role:grant` / `role:revoke` | ✓ | — | — |

每行至少一个测试用例,**反向用例**(越权 API 也要触发 1411/1403)。

### 5.7 可访问性 / UX
- 键盘:Tab 顺序 + Esc 关弹窗
- ScreenReader:Toast 角色、aria-label
- 错误吐司:错误信息可读
- 加载态:Spinner 不阻塞键盘

## 6. 测试环境与数据

- 后端:`Java :4001` + MySQL 3307 + 至少 3 个 admin 角色账号
  - `authtest_admin` / `AuthTest@12345`(admin 角色)
  - `authtest_viewer` / `AuthTest@12345`(viewer 角色)
  - `superadmin` 由 `ADMIN_BOOTSTRAP_*` env 启动时创建
- 前端:`vite preview` 跑 `dist/`(绕开 HMR)
- 测试用账号**不得**复用 `admin/admin123` 已有真实账号

## 7. 进入/退出准则

**进入下一阶段**:
- [ ] admin 三角色测试账号就绪
- [ ] MSW mock 与真实 backend 行为对齐(用 smoke.sh 验证后固定 schema)

**测试通过**:
- [ ] 单元 + 组件覆盖率 ≥ 80%
- [ ] 17 权限 × 3 角色矩阵 100% 覆盖
- [ ] 401/403 全路径触发
- [ ] 重置密码 / 角色变更 / 批量删除 三类破坏性操作有 confirm 路径
- [ ] E2E 7 个用例全绿

---

## 8. 待澄清/需用户决策

| 问题 | 选项 |
|---|---|
| 1. `AdminBusinessUsers` 批量删除需不需要「撤销 N 秒内」的二次确认? | A. 保留 B. 去掉 |
| 2. 测试用例是否覆盖 super_admin 的「越权也允许」验证(发 POST 到 `/api/admin/audit-logs` 也带 token)? | A. 覆盖(应返回 200)B. 不覆盖 |
| 3. CORS 跨域测试用什么工具? | A. Playwright B. 浏览器手动 |
| 4. CI 是否引入 admin 单独 pipeline? | A. 是 B. 否(用 smoke.sh) |

---

**生成时间**:2026-09-04
**生成方**:Claude (由 008.项目测试 目录工作流触发)