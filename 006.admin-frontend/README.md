# QingZhang Admin — Frontend

管理员后台 SPA。独立于主前端项目 (`frontend-react-java/`),通过主后端的 `/api/auth/login` + `/api/admin/*` 接口获取数据。

## 快速开始

**一键启停 (从仓库根):**
```bash
./start-admin           # 启动 → http://localhost:5174
./start-admin status    # 查端口/进程状态
./start-admin stop      # 停止
```

启动脚本 (与 `./start-backend` / `./start-frontend-react-java` 同风格) 自动:
- 检查端口 5174 占用 (占用则提示已运行)
- 安装依赖 (缺 `node_modules` 时)
- nohup 后台启动 + 写 PID 文件到 `/tmp/qz-admin-frontend.pid`
- 等待端口就绪并打印入口/日志路径

**手动启动:**
```bash
cd 006.admin-frontend
npm install
cp .env.example .env.local        # 设置 VITE_API_BASE
npm run dev                        # 启动 → http://localhost:5174
```

`.env.local`:
```env
VITE_API_BASE=http://localhost:8080
```

## 脚本

| 命令 | 作用 |
|------|------|
| `npm run dev` | 开发服务器 (5174) |
| `npm run build` | 生产构建到 `dist/` |
| `npm run preview` | 预览构建产物 |
| `npx tsc -b --noEmit` | 单独类型检查 |

## 技术栈

- **React 19.2** + **TypeScript 6** (strict mode)
- **Vite 8** (开发/构建)
- **react-router-dom 7** (嵌套路由 + Outlet)
- **Tailwind CSS 4** (通过 `@tailwindcss/vite`,主题色在 `src/index.css` 的 `@theme {}` 内定义)
- 无 Redux / Zustand —— React Context (`AdminAuthContext`) 就够

## 项目结构

```
src/
├── api/
│   ├── client.ts            # request<T>() + ApiError + token 持久化
│   └── types.ts             # 后端 DTO 一一对应的 TS 接口
├── auth/
│   ├── AdminAuthContext.tsx # user / permissions / roleCodes / isSuperAdmin
│   └── usePermissions.ts    # has(code) / hasAny(codes[]) —— super_admin 永远 true
├── components/
│   ├── ConfirmDialog.tsx    # confirm({title, body, danger?}) → Promise<boolean>
│   ├── DataTable.tsx        # 通用表格 + 分页 + 加载/空态
│   ├── KpiCard.tsx          # Dashboard 数字卡片
│   ├── PermissionGate.tsx   # <PermissionGate code="...">...</PermissionGate>
│   ├── ProtectedRoute.tsx    # 未登录跳 /login
│   └── Toast.tsx            # toast.success/error/info(msg)
├── layouts/
│   └── AdminLayout.tsx      # sidebar + header + <Outlet/>
├── pages/
│   ├── AdminAuditLogs.tsx   # /audit-logs (super_admin)
│   ├── AdminBooks.tsx       # /books
│   ├── AdminCategories.tsx  # /categories
│   ├── AdminDashboard.tsx   # /dashboard
│   ├── AdminLogin.tsx       # /login
│   ├── AdminRecords.tsx     # /records
│   └── AdminUsers.tsx       # /users
├── App.tsx                  # 路由表 + Providers 嵌套
├── main.tsx                 # 入口
└── index.css                # @tailwindcss + @theme 主题色
```

## 鉴权流程

1. 用户在 `/login` 提交 `{username, password}` → POST `/api/auth/login`
2. 后端返回 `{token, user, permissions, roleCodes, isSuperAdmin}`
3. 前端:
   - 存 `token` 到 `localStorage.admin_token`
   - `AdminAuthContext` 写入 user/permissions/roleCodes/isSuperAdmin
4. 路由守卫 `ProtectedRoute` 检查 `isAuthenticated`,未登录跳 `/login`
5. 已登录用户访问 `/login` 自动跳 `/dashboard`
6. 每次 mount 时若已有 token → 自动 GET `/api/admin/auth/me` 校验,失败则清空本地状态跳回登录
7. 401 响应 → `clearAuth()` + 跳登录

`request<T>()` 内部自动:
- 加 `Authorization: Bearer <token>`
- 401 时清本地态 + 抛 `ApiError`

## 权限系统

后端 V5 SQL 定义 17 个权限码 + 3 个角色:

| 角色 | 权限数 |
|------|--------|
| `super_admin` | 17 (全部) |
| `admin` | 14 (除 `audit:list`, `role:grant/revoke`) |
| `viewer` | 8 (只读) |

详见根目录 `ADMIN_README.md` 的权限矩阵。

### 前端用权限

```tsx
import { usePermissions } from '../auth/usePermissions'

const { has, hasAny, isSuperAdmin } = usePermissions()

// 1. 隐藏按钮
{has('user:disable') && <button>禁用</button>}

// 2. 包一层
<PermissionGate code="audit:list">
  <button>查看审计</button>
</PermissionGate>

// 3. super_admin 短路 —— 永远返回 true
```

完整权限码:`user:list`, `user:detail`, `user:disable`, `user:reset_password`, `user:grant_role`, `category:preset:list`, `category:preset:create`, `category:preset:update`, `category:preset:delete`, `book:list`, `book:view`, `record:list`, `record:view`, `dashboard:view`, `audit:list`, `role:grant`, `role:revoke`。

## 添加新页面

1. 在 `src/pages/` 下新建 `AdminXxx.tsx`,默认导出命名函数组件
2. 在 `App.tsx` 的 `<Route element={<ProtectedRoute><AdminLayout/></ProtectedRoute>}>` 内加 `<Route path="/xxx" element={<AdminXxx />} />`
3. 如果新页面需要权限,在 `AdminLayout.tsx` 的 `NAV` 数组加 `{to: '/xxx', label: 'Xxx', code: 'xxx:list'}`
4. 在 `src/api/types.ts` 加对应 DTO 接口(字段名严格匹配后端 record)
5. 用 `usePermissions()` 包需要权限的操作

## 与主前端的关系

- 共用后端 (`localhost:8080`)
- 端口不同 (主前端 5173 / admin 5174)
- token 存到独立 `localStorage.admin_token`,互不污染
- 登录复用 `/api/auth/login` —— 同一个 user 表;登录后 JWT 中带 admin 角色则可访问 `/api/admin/*`

## 调试

```bash
# 浏览器开发者工具 → Application → Local Storage:
#   admin_token     <- JWT
#   admin_user      (B2 添加过,可能为空)

# Network 面板看 /api/admin/* 请求的 Authorization header
# 后端日志看 admin_audit_logs 表是否记录了操作
```

## 已知限制 / v2 规划

- 无国际化 (中文硬编码)——v2 接 i18n
- 过滤器在组件 state,不支持 URL 分享——v2 接 react-router query params
- 无批量操作 / 导出 CSV——v2 加
- 无暗色主题——v2 加 `prefers-color-scheme` 媒体查询
- audit-logs 详情未实现抽屉/弹窗——v2 加

## 相关文档

- 根目录 `ADMIN_README.md` —— 后端 RBAC 矩阵 + 端点清单
- 根目录 `admin-smoke.sh` —— 后端 10 个核心场景冒烟脚本
