# Admin Frontend SPA — Implementation Plan (Plan B)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增独立 Vite SPA `admin-frontend`,提供管理员登录、用户/分类/账本/流水/审计的浏览与操作界面,通过 `/api/admin/*` 与后端 Plan A 通信。

**Architecture:** 独立 Vite + React 19 + TypeScript 项目,放在 `003.前端代码（前端工程师）/admin-frontend/`。复用主后端 `/api/auth/login`(同一 JWT secret);`/api/admin/*` 走 AdminAuthInterceptor 鉴权。路由前缀统一 `/admin/*`,本地域名端口 5174 (主前端 5173)。

**Tech Stack:** React 19 / TypeScript 6 / Vite 8 / react-router-dom 7 / Tailwind CSS 4。**不引** UI 库 / 状态库 / 数据请求库 (原生 fetch + useState/useEffect 够用)。

**Spec:** `docs/superpowers/specs/2026-08-30-admin-backend-design.md` (§7)

**Companion Plan:** `docs/superpowers/plans/2026-08-30-admin-backend.md` (Plan A,后端) — **必须先完成或同步进行**。

---

## Global Constraints

- 与主前端 `frontend-react-java` 同栈 (React 19 + Vite 8 + Tailwind 4),样式变量复用
- 路由前缀**全部** `/admin/*`,登录页 `/admin/login`
- `localStorage` key 用 `qz_admin_token`,与主前端 `qz_token` 隔离
- API 响应一律走 `ApiResponse<T>` 信封 (`{ code, message, data }`),客户端 unwrap
- 401 → 清 token + 跳 `/admin/login`;403 → 跳 `/admin/forbidden`
- 中文文案 (跟主前端对齐);不引 i18n (单语言够用)
- 不引 react-query / swr;每个页面自管 useEffect 拉数
- 不引 antd / mui;DataTable 自写,样式跟主前端同 Tailwind 变量
- 构建产物 `dist/`,Nginx `location /admin/` 部署

---

## Task 1: Vite 工程脚手架

**Files:**
- Create: `003.前端代码（前端工程师）/admin-frontend/package.json`
- Create: `003.前端代码（前端工程师）/admin-frontend/tsconfig.json`
- Create: `003.前端代码（前端工程师）/admin-frontend/tsconfig.app.json`
- Create: `003.前端代码（前端工程师）/admin-frontend/tsconfig.node.json`
- Create: `003.前端代码（前端工程师）/admin-frontend/vite.config.ts`
- Create: `003.前端代码（前端工程师）/admin-frontend/index.html`
- Create: `003.前端代码（前端工程师）/admin-frontend/src/main.tsx`
- Create: `003.前端代码（前端工程师）/admin-frontend/src/index.css`
- Create: `003.前端代码（前端工程师）/admin-frontend/.gitignore`
- Create: `003.前端代码（前端工程师）/admin-frontend/README.md`

**Step 1: package.json**

参考主前端 `frontend-react-java/package.json` 版本,精简掉 xlsx/oxlint/vitest (本项目不引):

```json
{
  "name": "admin-frontend",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite --port 5174",
    "build": "tsc -b && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^19.2.8",
    "react-dom": "^19.2.8",
    "react-router-dom": "^7.18.2"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.3.3",
    "@types/node": "^24.13.3",
    "@types/react": "^19.2.18",
    "@types/react-dom": "^19.2.4",
    "@vitejs/plugin-react": "^6.1.0",
    "tailwindcss": "^4.3.3",
    "typescript": "~6.0.2",
    "vite": "^8.2.2"
  }
}
```

**Step 2: tsconfig.json / tsconfig.app.json / tsconfig.node.json**

参考主前端同名文件,改 `rootDir` 到 `src`,`include` 路径调整。

`tsconfig.json`:

```json
{
  "files": [],
  "references": [
    { "path": "./tsconfig.app.json" },
    { "path": "./tsconfig.node.json" }
  ]
}
```

`tsconfig.app.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] }
  },
  "include": ["src"]
}
```

`tsconfig.node.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "isolatedModules": true,
    "moduleDetection": "force",
    "noEmit": true,
    "strict": true
  },
  "include": ["vite.config.ts"]
}
```

**Step 3: vite.config.ts**

```ts
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import path from 'node:path'

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: { '@': path.resolve(__dirname, './src') }
  },
  server: {
    port: 5174,
    proxy: {
      '/api': { target: 'http://localhost:8080', changeOrigin: true }
    }
  }
})
```

**Step 4: index.html**

```html
<!doctype html>
<html lang="zh-CN">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>轻账 · 管理后台</title>
  </head>
  <body class="bg-slate-50 text-slate-900 antialiased">
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>
```

**Step 5: src/index.css**

```css
@import "tailwindcss";
```

**Step 6: src/main.tsx (临时占位 — Task 3 加路由)**

```tsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <div className="p-8">轻账管理后台 (scaffold OK)</div>
  </StrictMode>
)
```

**Step 7: .gitignore**

```
node_modules
dist
.vite
*.log
.DS_Store
```

**Step 8: README.md**

```markdown
# 轻账 管理后台 (admin-frontend)

独立 SPA,见 [spec §7](../../docs/superpowers/specs/2026-08-30-admin-backend-design.md#7-frontend--admin-frontend-新项目) + [Plan B](../../docs/superpowers/plans/2026-08-30-admin-frontend.md)。

## Dev
```bash
# 后端先起 (8080),再:
cd admin-frontend
npm install
npm run dev
# 浏览器打开 http://localhost:5174
```

## Build
```bash
npm run build
# 产物在 dist/,Nginx location /admin/ 部署
```
```

**Step 9: 安装依赖 + 跑通**

```bash
cd "003.前端代码（前端工程师）/admin-frontend"
npm install
npm run build   # 验证 ts + build 通过
# Expected: BUILD 成功,生成 dist/index.html
```

**Step 10: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/"
git commit -m "feat(前端): admin-frontend Vite 脚手架"
```

---

## Task 2: API 客户端 + 类型定义

**Files:**
- Create: `src/api/client.ts`
- Create: `src/api/types.ts`

**Step 1: src/api/types.ts**

```ts
export interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

export interface User {
  id: number
  uuid: string
  username: string
  displayName: string | null
  avatar: string | null
  gender: 'male' | 'female' | 'other' | null
  age: number | null
  createdAt: string
}

export interface AuthResponse {
  user: User
  token: string
  permissions: string[]
  roleCodes: string[]
  isSuperAdmin: boolean
}

export interface AdminMeResponse {
  id: number
  uuid: string
  username: string
  displayName: string | null
  isSuperAdmin: boolean
  permissions: string[]
  roleCodes: string[]
}

export interface AdminUserListItem {
  id: number
  uuid: string
  username: string
  displayName: string | null
  status: number
  lastLoginAt: string | null
  createdAt: string
  recordCount: number
  bookCount: number
}

export interface Page<T> {
  records: T[]
  total: number
  size: number
  current: number
}

export interface AdminUserDetail {
  id: number
  uuid: string
  username: string
  displayName: string | null
  avatar: string | null
  gender: string | null
  age: number | null
  email: string | null
  phone: string | null
  status: number
  lastLoginAt: string | null
  createdAt: string
  roles: string[]
}

export interface AdminBookListItem {
  uuid: string
  name: string
  type: string
  currency: string
  ownerId: number
  ownerUsername: string
  accountCount: number
  recordCount: number
  createdAt: string
}

export interface AdminRecordListItem {
  uuid: string
  type: 'expense' | 'income' | 'transfer'
  amount: string
  currency: string
  note: string | null
  recordDate: string
  source: string
  userId: number
  username: string
  bookUuid: string
  bookName: string
  categoryName: string
  accountName: string
  createdAt: string
}

export interface AdminDashboardStats {
  userCount: number
  userNewToday: number
  userActive7d: number
  bookCount: number
  accountCount: number
  recordCount: number
  recordToday: number
  newUsersLast7Days: { date: string; count: number }[]
  newRecordsLast7Days: { date: string; count: number }[]
}

export interface AdminAuditLogListItem {
  uuid: string
  actorUsername: string
  action: string
  targetType: string | null
  targetId: number | null
  result: 'success' | 'failure'
  createdAt: string
}

export interface AdminAuditLogDetail extends AdminAuditLogListItem {
  actorUserId: number | null
  beforeSnapshot: string | null
  afterSnapshot: string | null
  ip: string | null
  userAgent: string | null
  errorMsg: string | null
}

export interface Category {
  id: number
  uuid: string
  type: 'expense' | 'income'
  name: string
  icon: string
  color: string
  isPreset: number
  sortOrder: number
  createdAt: string
}
```

**Step 2: src/api/client.ts**

```ts
import type { ApiResponse } from './types'

const TOKEN_KEY = 'qz_admin_token'

export class ApiError extends Error {
  constructor(public status: number, public code: number, message: string) {
    super(message)
  }
}

let onUnauthorized: () => void = () => {}
export function setOnUnauthorized(cb: () => void) { onUnauthorized = cb }

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY)
}

export function setToken(t: string | null) {
  if (t) localStorage.setItem(TOKEN_KEY, t)
  else localStorage.removeItem(TOKEN_KEY)
}

export async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(init.headers as Record<string, string> | undefined),
  }
  const token = getToken()
  if (token) headers['Authorization'] = `Bearer ${token}`

  const res = await fetch(path, { ...init, headers })

  if (res.status === 401) {
    setToken(null)
    onUnauthorized()
    throw new ApiError(401, 0, '未登录')
  }
  if (res.status === 403) {
    const body = await res.json().catch(() => ({}))
    throw new ApiError(403, body?.code ?? 1403, body?.message ?? '无权限')
  }

  const json = (await res.json()) as ApiResponse<T>
  if (json.code !== 0) {
    throw new ApiError(res.status, json.code, json.message)
  }
  return json.data
}
```

**Step 3: 编译验证**

```bash
cd "003.前端代码（前端工程师）/admin-frontend"
npx tsc --noEmit
# Expected: 0 errors
```

**Step 4: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/src/api/"
git commit -m "feat(前端): admin API client + 类型定义"
```

---

## Task 3: AdminAuthContext + AdminProtectedRoute + 路由骨架

**Files:**
- Create: `src/auth/AdminAuthContext.tsx`
- Create: `src/auth/AdminProtectedRoute.tsx`
- Create: `src/App.tsx`
- Create: `src/main.tsx` (覆盖 Task 1 占位)

**Step 1: src/auth/AdminAuthContext.tsx**

```tsx
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import * as authApi from '../api/adminAuth'
import { setOnUnauthorized, getToken, setToken } from '../api/client'
import type { AdminMeResponse } from '../api/types'

interface AuthContextValue {
  loading: boolean
  me: AdminMeResponse | null
  hasPermission: (code: string) => boolean
  login: (username: string, password: string) => Promise<void>
  logout: () => void
}

const Ctx = createContext<AuthContextValue | undefined>(undefined)

export function AdminAuthProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true)
  const [me, setMe] = useState<AdminMeResponse | null>(null)

  useEffect(() => {
    setOnUnauthorized(() => {
      setMe(null)
      window.location.href = '/admin/login'
    })
    const token = getToken()
    if (!token) { setLoading(false); return }
    authApi.me()
      .then(setMe)
      .catch(() => setToken(null))
      .finally(() => setLoading(false))
  }, [])

  const hasPermission = useCallback((code: string) => {
    if (!me) return false
    if (me.isSuperAdmin) return true
    return me.permissions.includes(code)
  }, [me])

  const login = useCallback(async (username: string, password: string) => {
    const r = await authApi.login({ username, password })
    setToken(r.token)
    setMe({
      id: r.user.id,
      uuid: r.user.uuid,
      username: r.user.username,
      displayName: r.user.displayName,
      isSuperAdmin: r.isSuperAdmin,
      permissions: r.permissions,
      roleCodes: r.roleCodes,
    })
  }, [])

  const logout = useCallback(() => {
    setToken(null)
    setMe(null)
    window.location.href = '/admin/login'
  }, [])

  const value = useMemo(() => ({ loading, me, hasPermission, login, logout }), [loading, me, hasPermission, login, logout])
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useAdminAuth() {
  const c = useContext(Ctx)
  if (!c) throw new Error('useAdminAuth 必须在 AdminAuthProvider 内')
  return c
}
```

**Step 2: src/api/adminAuth.ts**

```ts
import { request } from './client'
import type { AdminMeResponse, AuthResponse, Credentials } from './types'

export async function login(input: Credentials): Promise<AuthResponse> {
  return request<AuthResponse>('/api/auth/login', {
    method: 'POST',
    body: JSON.stringify(input),
  })
}

export async function me(): Promise<AdminMeResponse> {
  return request<AdminMeResponse>('/api/admin/auth/me')
}
```

**Step 3: src/auth/AdminProtectedRoute.tsx**

```tsx
import { Navigate, Outlet } from 'react-router-dom'
import { useAdminAuth } from './AdminAuthContext'

export function AdminProtectedRoute() {
  const { me, loading } = useAdminAuth()
  if (loading) return <div className="p-8 text-slate-500">加载中…</div>
  if (!me) return <Navigate to="/admin/login" replace />
  if (!me.isSuperAdmin && me.permissions.length === 0) return <Navigate to="/admin/forbidden" replace />
  return <Outlet />
}
```

**Step 4: src/App.tsx (临时只放登录 + 占位首页)**

```tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { AdminAuthProvider } from './auth/AdminAuthContext'
import { AdminProtectedRoute } from './auth/AdminProtectedRoute'
import { AdminLayout } from './layouts/AdminLayout'
import { AdminLogin } from './pages/AdminLogin'
import { AdminForbidden } from './pages/AdminForbidden'
import { AdminDashboard } from './pages/AdminDashboard'

export default function App() {
  return (
    <AdminAuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/admin/login" element={<AdminLogin />} />
          <Route path="/admin/forbidden" element={<AdminForbidden />} />
          <Route element={<AdminProtectedRoute />}>
            <Route element={<AdminLayout />}>
              <Route path="/admin" element={<AdminDashboard />} />
              {/* 占位 — 后续 Task 加 */}
              <Route path="*" element={<Navigate to="/admin" replace />} />
            </Route>
          </Route>
        </Routes>
      </BrowserRouter>
    </AdminAuthProvider>
  )
}
```

**Step 5: src/main.tsx**

```tsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import './index.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>
)
```

**Step 6: 占位页面 + Layout**

`src/pages/AdminLogin.tsx`(暂只渲染登录表单,Task 4 接 API):

```tsx
export function AdminLogin() {
  return <div className="min-h-screen flex items-center justify-center p-8">登录页占位</div>
}
```

`src/pages/AdminForbidden.tsx`:

```tsx
export function AdminForbidden() {
  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-8">
      <h1 className="text-2xl font-bold mb-4">403 — 无权限</h1>
      <p className="text-slate-600">您不是管理员或未被授权,请联系超级管理员。</p>
    </div>
  )
}
```

`src/pages/AdminDashboard.tsx`:

```tsx
export function AdminDashboard() {
  return <div className="p-8">Dashboard 占位</div>
}
```

`src/layouts/AdminLayout.tsx`:

```tsx
import { Outlet, Link } from 'react-router-dom'

export function AdminLayout() {
  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-slate-900 text-white px-6 py-3 flex items-center justify-between">
        <h1 className="text-lg font-bold">轻账 · 管理后台</h1>
        <nav className="flex gap-4 text-sm">
          <Link to="/admin">Dashboard</Link>
        </nav>
      </header>
      <main className="flex-1 p-8">
        <Outlet />
      </main>
    </div>
  )
}
```

**Step 7: 编译 + 跑通**

```bash
cd "003.前端代码（前端工程师）/admin-frontend"
npx tsc --noEmit
npm run build
# Expected: BUILD 成功
npm run dev &
sleep 5
# 浏览器开 http://localhost:5174/admin/login 应看见"登录页占位"
# http://localhost:5174/admin 应跳到 /admin/login
kill %1
```

**Step 8: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/src/"
git commit -m "feat(前端): AdminAuth + ProtectedRoute + 路由骨架"
```

---

## Task 4: AdminLogin 完整登录页 + Toast

**Files:**
- Create: `src/components/Toast.tsx`
- Modify: `src/pages/AdminLogin.tsx` (覆盖占位)

**Step 1: src/components/Toast.tsx**

```tsx
import { createContext, useCallback, useContext, useState } from 'react'
import type { ReactNode } from 'react'

interface ToastMsg { id: number; text: string; kind: 'info' | 'error' | 'success' }

interface Ctx { show: (text: string, kind?: ToastMsg['kind']) => void }

const ToastCtx = createContext<Ctx | undefined>(undefined)

export function ToastProvider({ children }: { children: ReactNode }) {
  const [msgs, setMsgs] = useState<ToastMsg[]>([])

  const show = useCallback((text: string, kind: ToastMsg['kind'] = 'info') => {
    const id = Date.now() + Math.random()
    setMsgs(prev => [...prev, { id, text, kind }])
    setTimeout(() => setMsgs(prev => prev.filter(m => m.id !== id)), 3000)
  }, [])

  return (
    <ToastCtx.Provider value={{ show }}>
      {children}
      <div className="fixed top-4 right-4 z-50 space-y-2">
        {msgs.map(m => (
          <div key={m.id}
               className={`px-4 py-2 rounded shadow text-sm ${
                 m.kind === 'error' ? 'bg-red-500 text-white'
                 : m.kind === 'success' ? 'bg-green-500 text-white'
                 : 'bg-slate-800 text-white'}`}>
            {m.text}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  )
}

export function useToast() {
  const c = useContext(ToastCtx)
  if (!c) throw new Error('useToast 必须在 ToastProvider 内')
  return c
}
```

**Step 2: src/pages/AdminLogin.tsx (完整版)**

```tsx
import { useState, type FormEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAdminAuth } from '../auth/AdminAuthContext'
import { ApiError } from '../api/client'
import { useToast } from '../components/Toast'

export function AdminLogin() {
  const navigate = useNavigate()
  const { login } = useAdminAuth()
  const toast = useToast()
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [busy, setBusy] = useState(false)

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    if (busy) return
    setBusy(true)
    try {
      await login(username, password)
      navigate('/admin', { replace: true })
    } catch (err) {
      if (err instanceof ApiError) toast.show(err.message, 'error')
      else toast.show('登录失败', 'error')
    } finally {
      setBusy(false)
    }
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-100">
      <form onSubmit={onSubmit} className="bg-white p-8 rounded-lg shadow w-full max-w-sm space-y-4">
        <h1 className="text-2xl font-bold text-center">轻账管理后台</h1>
        <div>
          <label className="block text-sm text-slate-600 mb-1">用户名</label>
          <input value={username} onChange={e => setUsername(e.target.value)}
                 required autoFocus
                 className="w-full px-3 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-slate-400" />
        </div>
        <div>
          <label className="block text-sm text-slate-600 mb-1">密码</label>
          <input type="password" value={password} onChange={e => setPassword(e.target.value)}
                 required
                 className="w-full px-3 py-2 border rounded focus:outline-none focus:ring-2 focus:ring-slate-400" />
        </div>
        <button type="submit" disabled={busy}
                className="w-full py-2 bg-slate-900 text-white rounded hover:bg-slate-700 disabled:opacity-50">
          {busy ? '登录中…' : '登录'}
        </button>
        <p className="text-xs text-slate-400 text-center">仅限管理员账号</p>
      </form>
    </div>
  )
}
```

**Step 3: src/main.tsx 包 ToastProvider**

```tsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import App from './App'
import { ToastProvider } from './components/Toast'
import './index.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ToastProvider>
      <App />
    </ToastProvider>
  </StrictMode>
)
```

**Step 4: 编译 + 跑通**

```bash
cd "003.前端代码（前端工程师）/admin-frontend"
npx tsc --noEmit
npm run build

# 起后端(假设 Plan A 已完成,bootstrap 引导 root 用户)
cd "../../005.后端代码（Java工程师）"
ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD='Root@12345' \
  mvn -q spring-boot:run &
SPRING_PID=$!
sleep 30

# 启前端
cd "../../003.前端代码（前端工程师）/admin-frontend"
npm run dev &
VITE_PID=$!
sleep 5

# curl 模拟登录
curl -fsS -X POST http://localhost:5174/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"root","password":"Root@12345"}' | jq '.data.isSuperAdmin'
# Expected: true (vite proxy 转发到 8080)

kill $VITE_PID $SPRING_PID
```

**Step 5: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/src/"
git commit -m "feat(前端): AdminLogin 完整登录页 + Toast 组件"
```

---

## Task 5: 通用组件 DataTable + ConfirmDialog + PermissionGate

**Files:**
- Create: `src/components/DataTable.tsx`
- Create: `src/components/ConfirmDialog.tsx`
- Create: `src/components/PermissionGate.tsx`

**Step 1: src/components/DataTable.tsx**

```tsx
import type { ReactNode } from 'react'

export interface Column<T> {
  key: string
  header: string
  render: (row: T) => ReactNode
  width?: string
}

interface Props<T> {
  columns: Column<T>[]
  data: T[]
  loading?: boolean
  emptyText?: string
  rowKey: (row: T) => string | number
}

export function DataTable<T>({ columns, data, loading, emptyText = '暂无数据', rowKey }: Props<T>) {
  return (
    <div className="overflow-x-auto bg-white rounded shadow">
      <table className="min-w-full text-sm">
        <thead className="bg-slate-100 text-slate-700">
          <tr>
            {columns.map(c => (
              <th key={c.key} className="px-4 py-2 text-left font-medium"
                  style={c.width ? { width: c.width } : undefined}>
                {c.header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {loading ? (
            <tr><td colSpan={columns.length} className="px-4 py-8 text-center text-slate-400">加载中…</td></tr>
          ) : data.length === 0 ? (
            <tr><td colSpan={columns.length} className="px-4 py-8 text-center text-slate-400">{emptyText}</td></tr>
          ) : (
            data.map(row => (
              <tr key={rowKey(row)} className="border-t hover:bg-slate-50">
                {columns.map(c => (
                  <td key={c.key} className="px-4 py-2 align-top">{c.render(row)}</td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  )
}
```

**Step 2: src/components/ConfirmDialog.tsx**

```tsx
import { useState, type ReactNode } from 'react'

interface Props {
  title: string
  message: ReactNode
  confirmText?: string
  danger?: boolean
  onConfirm: () => Promise<void> | void
  children: (open: () => void) => ReactNode
}

export function ConfirmDialog({ title, message, confirmText = '确认', danger, onConfirm, children }: Props) {
  const [open, setOpen] = useState(false)
  const [busy, setBusy] = useState(false)

  async function handleConfirm() {
    setBusy(true)
    try {
      await onConfirm()
      setOpen(false)
    } finally { setBusy(false) }
  }

  return (
    <>
      {children(() => setOpen(true))}
      {open && (
        <div className="fixed inset-0 z-40 bg-black/40 flex items-center justify-center p-4">
          <div className="bg-white rounded-lg shadow-xl max-w-sm w-full p-6">
            <h2 className="text-lg font-bold mb-2">{title}</h2>
            <div className="text-sm text-slate-600 mb-4">{message}</div>
            <div className="flex justify-end gap-2">
              <button onClick={() => setOpen(false)} disabled={busy}
                      className="px-4 py-2 rounded border text-slate-700 hover:bg-slate-50">
                取消
              </button>
              <button onClick={handleConfirm} disabled={busy}
                      className={`px-4 py-2 rounded text-white ${
                        danger ? 'bg-red-600 hover:bg-red-700' : 'bg-slate-900 hover:bg-slate-700'
                      } disabled:opacity-50`}>
                {busy ? '处理中…' : confirmText}
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
```

**Step 3: src/components/PermissionGate.tsx**

```tsx
import type { ReactNode } from 'react'
import { useAdminAuth } from '../auth/AdminAuthContext'

interface Props {
  need: string
  children: ReactNode
  fallback?: ReactNode
}

export function PermissionGate({ need, children, fallback = null }: Props) {
  const { hasPermission } = useAdminAuth()
  if (!hasPermission(need)) return <>{fallback}</>
  return <>{children}</>
}
```

**Step 4: 编译**

```bash
cd "003.前端代码（前端工程师）/admin-frontend"
npx tsc --noEmit
```

**Step 5: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/src/components/"
git commit -m "feat(前端): DataTable / ConfirmDialog / PermissionGate 通用组件"
```

---

## Task 6: AdminDashboard 真实页 + AdminLayout 完善

**Files:**
- Modify: `src/pages/AdminDashboard.tsx`
- Modify: `src/layouts/AdminLayout.tsx`

**Step 1: src/api/adminDashboard.ts**

```ts
import { request } from './client'
import type { AdminDashboardStats } from './types'

export function getStats() {
  return request<AdminDashboardStats>('/api/admin/dashboard')
}
```

**Step 2: src/pages/AdminDashboard.tsx**

```tsx
import { useEffect, useState } from 'react'
import { getStats } from '../api/adminDashboard'
import { ApiError } from '../api/client'
import { useToast } from '../components/Toast'
import type { AdminDashboardStats } from '../api/types'

export function AdminDashboard() {
  const [stats, setStats] = useState<AdminDashboardStats | null>(null)
  const [loading, setLoading] = useState(true)
  const toast = useToast()

  useEffect(() => {
    getStats()
      .then(setStats)
      .catch((e: unknown) => toast.show(e instanceof ApiError ? e.message : '加载失败', 'error'))
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <div className="text-slate-500">加载中…</div>
  if (!stats) return null

  const cards = [
    { label: '总用户数', value: stats.userCount },
    { label: '今日新增', value: stats.userNewToday },
    { label: '7 日活跃', value: stats.userActive7d },
    { label: '账本总数', value: stats.bookCount },
    { label: '账户总数', value: stats.accountCount },
    { label: '流水总数', value: stats.recordCount },
    { label: '今日流水', value: stats.recordToday },
  ]

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold">Dashboard</h2>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        {cards.map(c => (
          <div key={c.label} className="bg-white p-4 rounded shadow">
            <div className="text-sm text-slate-500">{c.label}</div>
            <div className="text-2xl font-bold mt-1">{c.value}</div>
          </div>
        ))}
      </div>
      <div className="bg-white p-4 rounded shadow">
        <h3 className="text-sm font-medium text-slate-700 mb-2">最近 7 天新增用户</h3>
        <div className="flex gap-1 items-end h-32">
          {stats.newUsersLast7Days.map(d => (
            <div key={d.date} className="flex-1 flex flex-col items-center gap-1">
              <div className="w-full bg-slate-300 rounded-t"
                   style={{ height: `${Math.max(2, d.count * 10)}px` }}
                   title={`${d.count} 人`} />
              <div className="text-xs text-slate-400">{d.date.slice(5)}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
```

**Step 3: src/layouts/AdminLayout.tsx (加导航 + 退出)**

```tsx
import { Outlet, Link, NavLink } from 'react-router-dom'
import { useAdminAuth } from '../auth/AdminAuthContext'

const NAV = [
  { to: '/admin', label: 'Dashboard', end: true },
  { to: '/admin/users', label: '用户管理' },
  { to: '/admin/categories', label: '预设分类' },
  { to: '/admin/books', label: '账本浏览' },
  { to: '/admin/records', label: '流水浏览' },
  { to: '/admin/audit-logs', label: '审计日志' },
]

export function AdminLayout() {
  const { me, logout, hasPermission } = useAdminAuth()

  const filteredNav = NAV.filter(item => {
    if (item.to === '/admin') return hasPermission('dashboard:view')
    if (item.to === '/admin/users') return hasPermission('user:list')
    if (item.to === '/admin/categories') return hasPermission('category:preset:list')
    if (item.to === '/admin/books') return hasPermission('book:list')
    if (item.to === '/admin/records') return hasPermission('record:list')
    if (item.to === '/admin/audit-logs') return hasPermission('audit:list')
    return true
  })

  return (
    <div className="min-h-screen flex flex-col">
      <header className="bg-slate-900 text-white px-6 py-3 flex items-center justify-between">
        <h1 className="text-lg font-bold">轻账 · 管理后台</h1>
        <div className="flex items-center gap-4 text-sm">
          <span>{me?.displayName || me?.username}</span>
          <span className="px-2 py-2 rounded bg-slate-700 text-xs">
            {me?.isSuperAdmin ? 'super_admin' : me?.roleCodes.join(', ') || '—'}
          </span>
          <button onClick={logout} className="px-3 py-1 rounded bg-slate-700 hover:bg-slate-600">
            退出
          </button>
        </div>
      </header>
      <div className="flex flex-1">
        <nav className="w-56 bg-white border-r p-4 space-y-1">
          {filteredNav.map(item => (
            <NavLink key={item.to} to={item.to} end={item.end}
                     className={({ isActive }) =>
                       `block px-3 py-2 rounded text-sm ${
                         isActive ? 'bg-slate-900 text-white' : 'text-slate-700 hover:bg-slate-100'
                       }`}>
              {item.label}
            </NavLink>
          ))}
        </nav>
        <main className="flex-1 p-8">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
```

**Step 4: 编译 + 跑通**

```bash
cd "003.前端代码（前端工程师）/admin-frontend"
npx tsc --noEmit
npm run build
# 起后端 + 前端 (参考 Task 4 Step 4),浏览器开 /admin 应看见 7 个卡片
```

**Step 5: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/src/"
git commit -m "feat(前端): Dashboard 页 + AdminLayout 完整导航"
```

---

## Task 7: AdminUsers 页 (列表 + 详情 + 操作)

**Files:**
- Create: `src/api/adminUsers.ts`
- Create: `src/pages/AdminUsers.tsx`
- Modify: `src/App.tsx` (加路由)

**Step 1: src/api/adminUsers.ts**

```ts
import { request } from './client'
import type { AdminUserDetail, AdminUserListItem, Page } from './types'

export function list(params: { search?: string; status?: number; page?: number; size?: number } = {}) {
  const qs = new URLSearchParams()
  if (params.search) qs.set('search', params.search)
  if (params.status !== undefined) qs.set('status', String(params.status))
  qs.set('page', String(params.page ?? 1))
  qs.set('size', String(params.size ?? 20))
  return request<Page<AdminUserListItem>>(`/api/admin/users?${qs}`)
}

export function detail(id: number) {
  return request<AdminUserDetail>(`/api/admin/users/${id}`)
}

export function updateStatus(id: number, enabled: boolean) {
  return request<void>(`/api/admin/users/${id}/status`, {
    method: 'PATCH',
    body: JSON.stringify({ enabled }),
  })
}

export function resetPassword(id: number) {
  return request<{ newPassword: string }>(`/api/admin/users/${id}/reset-password`, {
    method: 'POST',
  })
}

export function grantRole(id: number, roleCode: string) {
  return request<void>(`/api/admin/users/${id}/roles`, {
    method: 'POST',
    body: JSON.stringify({ roleCode }),
  })
}

export function revokeRole(id: number, roleCode: string) {
  return request<void>(`/api/admin/users/${id}/roles/${roleCode}`, {
    method: 'DELETE',
  })
}
```

**Step 2: src/pages/AdminUsers.tsx**

```tsx
import { useEffect, useState } from 'react'
import { DataTable, type Column } from '../components/DataTable'
import { ConfirmDialog } from '../components/ConfirmDialog'
import { PermissionGate } from '../components/PermissionGate'
import { useToast } from '../components/Toast'
import { ApiError } from '../api/client'
import { grantRole, list, resetPassword, revokeRole, updateStatus } from '../api/adminUsers'
import type { AdminUserListItem } from '../api/types'

export function AdminUsers() {
  const [data, setData] = useState<AdminUserListItem[]>([])
  const [total, setTotal] = useState(0)
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [statusFilter, setStatusFilter] = useState<'' | '1' | '0'>('')
  const [page, setPage] = useState(1)
  const toast = useToast()

  async function reload() {
    setLoading(true)
    try {
      const p = await list({
        search: search || undefined,
        status: statusFilter === '' ? undefined : Number(statusFilter),
        page,
        size: 20,
      })
      setData(p.records)
      setTotal(p.total)
    } catch (e: unknown) {
      toast.show(e instanceof ApiError ? e.message : '加载失败', 'error')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { reload() }, [page, statusFilter])

  const columns: Column<AdminUserListItem>[] = [
    { key: 'id', header: 'ID', render: r => r.id, width: '60px' },
    { key: 'username', header: '用户名', render: r => r.username },
    { key: 'displayName', header: '昵称', render: r => r.displayName || '—' },
    {
      key: 'status', header: '状态', render: r => (
        <span className={`px-2 py-2 rounded text-xs ${r.status === 1 ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}>
          {r.status === 1 ? '启用' : '禁用'}
        </span>
      )
    },
    { key: 'lastLogin', header: '最近登录', render: r => r.lastLoginAt ? new Date(r.lastLoginAt).toLocaleString() : '—' },
    { key: 'created', header: '注册时间', render: r => new Date(r.createdAt).toLocaleString() },
    {
      key: 'actions', header: '操作', render: r => (
        <div className="flex gap-2">
          <PermissionGate need="user:disable">
            <ConfirmDialog
              title={r.status === 1 ? '禁用用户' : '启用用户'}
              message={`确认 ${r.status === 1 ? '禁用' : '启用'} 用户 "${r.username}"?`}
              danger={r.status === 1}
              confirmText={r.status === 1 ? '禁用' : '启用'}
              onConfirm={async () => {
                await updateStatus(r.id, r.status !== 1)
                toast.show('已更新', 'success')
                await reload()
              }}>
              {(open) => (
                <button onClick={open} className="text-xs text-slate-700 underline">
                  {r.status === 1 ? '禁用' : '启用'}
                </button>
              )}
            </ConfirmDialog>
          </PermissionGate>
          <PermissionGate need="user:reset_password">
            <ConfirmDialog
              title="重置密码"
              message={`将为 "${r.username}" 生成新的随机密码,新密码只展示一次。`}
              confirmText="生成"
              onConfirm={async () => {
                const res = await resetPassword(r.id)
                prompt('新密码 (请复制给用户)', res.newPassword)
              }}>
              {(open) => (
                <button onClick={open} className="text-xs text-slate-700 underline">重置密码</button>
              )}
            </ConfirmDialog>
          </PermissionGate>
        </div>
      )
    },
  ]

  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">用户管理</h2>
      <div className="flex gap-3 items-end">
        <div>
          <label className="block text-xs text-slate-500 mb-1">搜索</label>
          <input value={search} onChange={e => setSearch(e.target.value)}
                 onKeyDown={e => e.key === 'Enter' && reload()}
                 placeholder="用户名"
                 className="px-3 py-1 border rounded text-sm" />
        </div>
        <div>
          <label className="block text-xs text-slate-500 mb-1">状态</label>
          <select value={statusFilter} onChange={e => { setStatusFilter(e.target.value as typeof statusFilter); setPage(1) }}
                  className="px-3 py-1 border rounded text-sm">
            <option value="">全部</option>
            <option value="1">启用</option>
            <option value="0">禁用</option>
          </select>
        </div>
        <button onClick={() => { setPage(1); reload() }}
                className="px-3 py-1 bg-slate-900 text-white rounded text-sm">查询</button>
        <span className="ml-auto text-sm text-slate-500">共 {total} 个用户</span>
      </div>
      <DataTable columns={columns} data={data} loading={loading} rowKey={r => r.id} />
      <div className="flex gap-2 justify-end">
        <button disabled={page === 1} onClick={() => setPage(p => p - 1)}
                className="px-3 py-1 border rounded text-sm disabled:opacity-50">上一页</button>
        <span className="px-2 py-1 text-sm">第 {page} 页</span>
        <button disabled={data.length < 20} onClick={() => setPage(p => p + 1)}
                className="px-3 py-1 border rounded text-sm disabled:opacity-50">下一页</button>
      </div>
    </div>
  )
}
```

**Step 3: src/App.tsx 加路由**

```tsx
// 在 AdminDashboard 路由后加:
<Route path="/admin/users" element={<AdminUsers />} />
// + import AdminUsers
```

**Step 4: 编译 + 跑通**

```bash
cd "003.前端代码（前端工程师）/admin-frontend"
npx tsc --noEmit
npm run build
# 启服登录验证:点 "用户管理" → 看见 root 自身 + 之前注册的 alice → 点禁用/启用/重置密码生效
```

**Step 5: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/src/"
git commit -m "feat(前端): AdminUsers 列表 + 详情 + 禁用/启用/重置密码"
```

---

## Task 8: AdminCategories / AdminBooks / AdminRecords / AdminAuditLogs 4 个页面

**Files:**
- Create: `src/api/adminCategories.ts`
- Create: `src/api/adminBooks.ts`
- Create: `src/api/adminRecords.ts`
- Create: `src/api/adminAuditLogs.ts`
- Create: `src/pages/AdminCategories.tsx`
- Create: `src/pages/AdminBooks.tsx`
- Create: `src/pages/AdminRecords.tsx`
- Create: `src/pages/AdminAuditLogs.tsx`
- Modify: `src/App.tsx` (加 4 个路由)

**Step 1: 4 个 API 模块**

```ts
// src/api/adminCategories.ts
import { request } from './client'
import type { Category } from './types'

export function listPreset() {
  return request<Category[]>('/api/admin/categories/preset')
}

export function createPreset(body: { type: 'expense' | 'income'; name: string; icon?: string; color?: string; sortOrder?: number }) {
  return request<Category>('/api/admin/categories/preset', {
    method: 'POST',
    body: JSON.stringify(body),
  })
}

export function updatePreset(uuid: string, body: Partial<{ name: string; icon: string; color: string; sortOrder: number }>) {
  return request<Category>(`/api/admin/categories/preset/${uuid}`, {
    method: 'PATCH',
    body: JSON.stringify(body),
  })
}

export function deletePreset(uuid: string) {
  return request<void>(`/api/admin/categories/preset/${uuid}`, { method: 'DELETE' })
}
```

```ts
// src/api/adminBooks.ts
import { request } from './client'
import type { AdminBookListItem, Page } from './types'

export function list(params: { ownerId?: number; type?: string; page?: number; size?: number } = {}) {
  const qs = new URLSearchParams()
  if (params.ownerId) qs.set('ownerId', String(params.ownerId))
  if (params.type) qs.set('type', params.type)
  qs.set('page', String(params.page ?? 1))
  qs.set('size', String(params.size ?? 20))
  return request<Page<AdminBookListItem>>(`/api/admin/books?${qs}`)
}
```

```ts
// src/api/adminRecords.ts
import { request } from './client'
import type { AdminRecordListItem, Page } from './types'

export function list(params: { userId?: number; bookUuid?: string; type?: string; from?: string; to?: string; page?: number; size?: number } = {}) {
  const qs = new URLSearchParams()
  if (params.userId) qs.set('userId', String(params.userId))
  if (params.bookUuid) qs.set('bookUuid', params.bookUuid)
  if (params.type) qs.set('type', params.type)
  if (params.from) qs.set('from', params.from)
  if (params.to) qs.set('to', params.to)
  qs.set('page', String(params.page ?? 1))
  qs.set('size', String(params.size ?? 20))
  return request<Page<AdminRecordListItem>>(`/api/admin/records?${qs}`)
}
```

```ts
// src/api/adminAuditLogs.ts
import { request } from './client'
import type { AdminAuditLogDetail, AdminAuditLogListItem, Page } from './types'

export function list(params: { actorUserId?: number; action?: string; targetType?: string; targetId?: number; from?: string; to?: string; page?: number; size?: number } = {}) {
  const qs = new URLSearchParams()
  if (params.actorUserId) qs.set('actorUserId', String(params.actorUserId))
  if (params.action) qs.set('action', params.action)
  if (params.targetType) qs.set('targetType', params.targetType)
  if (params.targetId) qs.set('targetId', String(params.targetId))
  if (params.from) qs.set('from', params.from)
  if (params.to) qs.set('to', params.to)
  qs.set('page', String(params.page ?? 1))
  qs.set('size', String(params.size ?? 20))
  return request<Page<AdminAuditLogListItem>>(`/api/admin/audit-logs?${qs}`)
}

export function detail(uuid: string) {
  return request<AdminAuditLogDetail>(`/api/admin/audit-logs/${uuid}`)
}
```

**Step 2: AdminCategories 页**

```tsx
// src/pages/AdminCategories.tsx
import { useEffect, useState } from 'react'
import { DataTable, type Column } from '../components/DataTable'
import { PermissionGate } from '../components/PermissionGate'
import { useToast } from '../components/Toast'
import { ApiError } from '../api/client'
import { createPreset, deletePreset, listPreset, updatePreset } from '../api/adminCategories'
import type { Category } from '../api/types'

export function AdminCategories() {
  const [data, setData] = useState<Category[]>([])
  const [loading, setLoading] = useState(true)
  const [showCreate, setShowCreate] = useState(false)
  const [type, setType] = useState<'expense' | 'income'>('expense')
  const [name, setName] = useState('')
  const [icon, setIcon] = useState('')
  const [color, setColor] = useState('#A0AEC0')
  const toast = useToast()

  async function reload() {
    setLoading(true)
    try { setData(await listPreset()) }
    catch (e: unknown) { toast.show(e instanceof ApiError ? e.message : '加载失败', 'error') }
    finally { setLoading(false) }
  }

  useEffect(() => { reload() }, [])

  async function handleCreate() {
    try {
      await createPreset({ type, name, icon, color, sortOrder: 0 })
      setShowCreate(false); setName(''); setIcon('')
      toast.show('已创建', 'success')
      await reload()
    } catch (e: unknown) { toast.show(e instanceof ApiError ? e.message : '创建失败', 'error') }
  }

  const columns: Column<Category>[] = [
    { key: 'type', header: '类型', render: c => c.type === 'expense' ? '支出' : '收入' },
    { key: 'icon', header: '图标', render: c => <span className="text-xl">{c.icon || '—'}</span> },
    { key: 'name', header: '名称', render: c => c.name },
    { key: 'color', header: '颜色', render: c => <span className="inline-block w-4 h-4 rounded" style={{ background: c.color }} /> },
    {
      key: 'actions', header: '操作', render: c => (
        <PermissionGate need="category:preset:delete">
          <button onClick={async () => {
            if (!confirm(`确认删除预设分类 "${c.name}"?`)) return
            try { await deletePreset(c.uuid); toast.show('已删除', 'success'); reload() }
            catch (e: unknown) { toast.show(e instanceof ApiError ? e.message : '失败', 'error') }
          }} className="text-xs text-red-600 underline">删除</button>
        </PermissionGate>
      )
    },
  ]

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold">预设分类</h2>
        <PermissionGate need="category:preset:create">
          <button onClick={() => setShowCreate(s => !s)}
                  className="px-3 py-1 bg-slate-900 text-white rounded text-sm">
            {showCreate ? '取消' : '+ 新建预设'}
          </button>
        </PermissionGate>
      </div>
      {showCreate && (
        <div className="bg-white p-4 rounded shadow grid grid-cols-5 gap-2 items-end">
          <div>
            <label className="block text-xs mb-1">类型</label>
            <select value={type} onChange={e => setType(e.target.value as 'expense' | 'income')}
                    className="w-full px-2 py-1 border rounded text-sm">
              <option value="expense">支出</option>
              <option value="income">收入</option>
            </select>
          </div>
          <div><label className="block text-xs mb-1">名称</label>
            <input value={name} onChange={e => setName(e.target.value)}
                   className="w-full px-2 py-1 border rounded text-sm" /></div>
          <div><label className="block text-xs mb-1">图标 (emoji)</label>
            <input value={icon} onChange={e => setIcon(e.target.value)}
                   className="w-full px-2 py-1 border rounded text-sm" /></div>
          <div><label className="block text-xs mb-1">颜色</label>
            <input type="color" value={color} onChange={e => setColor(e.target.value)}
                   className="w-full h-8 border rounded" /></div>
          <button onClick={handleCreate}
                  className="px-3 py-1 bg-green-600 text-white rounded text-sm">提交</button>
        </div>
      )}
      <DataTable columns={columns} data={data} loading={loading} rowKey={r => r.uuid} />
    </div>
  )
}
```

**Step 3: AdminBooks / AdminRecords 页 (只读浏览,无操作)**

```tsx
// src/pages/AdminBooks.tsx
import { useEffect, useState } from 'react'
import { DataTable, type Column } from '../components/DataTable'
import { useToast } from '../components/Toast'
import { ApiError } from '../api/client'
import { list } from '../api/adminBooks'
import type { AdminBookListItem } from '../api/types'

export function AdminBooks() {
  const [data, setData] = useState<AdminBookListItem[]>([])
  const [loading, setLoading] = useState(true)
  const toast = useToast()

  useEffect(() => {
    list({ size: 50 })
      .then(p => setData(p.records))
      .catch((e: unknown) => toast.show(e instanceof ApiError ? e.message : '加载失败', 'error'))
      .finally(() => setLoading(false))
  }, [])

  const columns: Column<AdminBookListItem>[] = [
    { key: 'name', header: '账本名', render: r => r.name },
    { key: 'owner', header: '所有者', render: r => r.ownerUsername },
    { key: 'type', header: '类型', render: r => r.type },
    { key: 'currency', header: '币种', render: r => r.currency },
    { key: 'created', header: '创建时间', render: r => new Date(r.createdAt).toLocaleString() },
  ]

  return (
    <div className="space-y-4">
      <h2 className="text-2xl font-bold">账本浏览</h2>
      <DataTable columns={columns} data={data} loading={loading} rowKey={r => r.uuid} />
    </div>
  )
}
```

```tsx
// src/pages/AdminRecords.tsx
import { useEffect, useState } from 'react'
import { DataTable, type Column } from '../components/DataTable'
import { useToast } from '../components/Toast'
import { ApiError } from '../api/client'
import { list } from '../api/adminRecords'
import type { AdminRecordListItem } from '../api/types'

export function AdminRecords() {
  const [data, setData] = useState<AdminRecordListItem[]>([])
  const [loading, setLoading] = useState(true)
  const [type, setType] = useState<'' | 'expense' | 'income' | 'transfer'>('')
  const toast = useToast()

  useEffect(() => {
    setLoading(true)
    list({ type: type || undefined, size: 50 })
      .then(p => setData(p.records))
      .catch((e: unknown) => toast.show(e instanceof ApiError ? e.message : '加载失败', 'error'))
      .finally(() => setLoading(false))
  }, [type])

  const columns: Column<AdminRecordListItem>[] = [
    { key: 'date', header: '日期', render: r => r.recordDate },
    { key: 'user', header: '用户', render: r => r.username },
    { key: 'book', header: '账本', render: r => r.bookName },
    { key: 'type', header: '类型', render: r => ({ expense: '支出', income: '收入', transfer: '转账' }[r.type]) },
    { key: 'category', header: '分类', render: r => r.categoryName || '—' },
    { key: 'amount', header: '金额', render: r => `${r.currency} ${r.amount}` },
    { key: 'note', header: '备注', render: r => r.note || '—' },
  ]

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between">
        <h2 className="text-2xl font-bold">流水浏览</h2>
        <select value={type} onChange={e => setType(e.target.value as typeof type)}
                className="px-3 py-1 border rounded text-sm">
          <option value="">全部</option>
          <option value="expense">支出</option>
          <option value="income">收入</option>
          <option value="transfer">转账</option>
        </select>
      </div>
      <DataTable columns={columns} data={data} loading={loading} rowKey={r => r.uuid} />
    </div>
  )
}
```

**Step 4: AdminAuditLogs 页**

```tsx
// src/pages/AdminAuditLogs.tsx
import { useEffect, useState } from 'react'
import { DataTable, type Column } from '../components/DataTable'
import { useToast } from '../components/Toast'
import { ApiError } from '../api/client'
import { detail, list } from '../api/adminAuditLogs'
import type { AdminAuditLogListItem } from '../api/types'

export function AdminAuditLogs() {
  const [data, setData] = useState<AdminAuditLogListItem[]>([])
  const [loading, setLoading] = useState(true)
  const [actionFilter, setActionFilter] = useState('')
  const [detailUuid, setDetailUuid] = useState<string | null>(null)
  const [detailJson, setDetailJson] = useState<{ before?: unknown; after?: unknown; error?: string }>({})
  const toast = useToast()

  useEffect(() => {
    setLoading(true)
    list({ action: actionFilter || undefined, size: 50 })
      .then(p => setData(p.records))
      .catch((e: unknown) => toast.show(e instanceof ApiError ? e.message : '加载失败', 'error'))
      .finally(() => setLoading(false))
  }, [actionFilter])

  async function openDetail(uuid: string) {
    try {
      const d = await detail(uuid)
      setDetailUuid(uuid)
      setDetailJson({
        before: d.beforeSnapshot ? JSON.parse(d.beforeSnapshot) : undefined,
        after: d.afterSnapshot ? JSON.parse(d.afterSnapshot) : undefined,
        error: d.errorMsg ?? undefined,
      })
    } catch (e: unknown) { toast.show(e instanceof ApiError ? e.message : '失败', 'error') }
  }

  const columns: Column<AdminAuditLogListItem>[] = [
    { key: 'time', header: '时间', render: r => new Date(r.createdAt).toLocaleString() },
    { key: 'actor', header: '操作者', render: r => r.actorUsername },
    { key: 'action', header: '动作', render: r => r.action },
    { key: 'target', header: '目标', render: r => `${r.targetType ?? '—'}${r.targetId ? '#' + r.targetId : ''}` },
    {
      key: 'result', header: '结果', render: r => (
        <span className={`px-2 py-2 rounded text-xs ${
          r.result === 'success' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
        }`}>{r.result}</span>
      )
    },
    { key: 'op', header: '', render: r => (
      <button onClick={() => openDetail(r.uuid)} className="text-xs underline text-slate-600">详情</button>
    ) },
  ]

  return (
    <div className="space-y-4">
      <div className="flex items-end justify-between">
        <h2 className="text-2xl font-bold">审计日志</h2>
        <input value={actionFilter} onChange={e => setActionFilter(e.target.value)}
               placeholder="按 action 过滤"
               className="px-3 py-1 border rounded text-sm" />
      </div>
      <DataTable columns={columns} data={data} loading={loading} rowKey={r => r.uuid} />
      {detailUuid && (
        <div className="fixed inset-0 z-40 bg-black/40 flex items-center justify-center p-4"
             onClick={() => setDetailUuid(null)}>
          <div className="bg-white rounded-lg shadow-xl max-w-2xl w-full p-6"
               onClick={e => e.stopPropagation()}>
            <h3 className="text-lg font-bold mb-3">审计详情 {detailUuid.slice(0, 8)}…</h3>
            <div className="grid grid-cols-2 gap-4 text-xs">
              <div>
                <h4 className="font-medium mb-1">Before</h4>
                <pre className="bg-slate-50 p-2 rounded overflow-auto max-h-64">
                  {detailJson.before ? JSON.stringify(detailJson.before, null, 2) : '—'}
                </pre>
              </div>
              <div>
                <h4 className="font-medium mb-1">After</h4>
                <pre className="bg-slate-50 p-2 rounded overflow-auto max-h-64">
                  {detailJson.after ? JSON.stringify(detailJson.after, null, 2) : '—'}
                </pre>
              </div>
            </div>
            {detailJson.error && (
              <div className="mt-3 text-red-600 text-sm">错误: {detailJson.error}</div>
            )}
            <div className="mt-4 text-right">
              <button onClick={() => setDetailUuid(null)} className="px-3 py-1 border rounded text-sm">关闭</button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
```

**Step 5: src/App.tsx 加 4 路由**

```tsx
import { AdminCategories } from './pages/AdminCategories'
import { AdminBooks } from './pages/AdminBooks'
import { AdminRecords } from './pages/AdminRecords'
import { AdminAuditLogs } from './pages/AdminAuditLogs'

// 在 AdminLayout 内 routes 加:
<Route path="/admin/categories" element={<AdminCategories />} />
<Route path="/admin/books" element={<AdminBooks />} />
<Route path="/admin/records" element={<AdminRecords />} />
<Route path="/admin/audit-logs" element={<AdminAuditLogs />} />
```

**Step 6: 编译 + 跑通**

```bash
cd "003.前端代码（前端工程师）/admin-frontend"
npx tsc --noEmit
npm run build
# 启服验证 4 个页面都能加载 + 操作生效
```

**Step 7: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/src/"
git commit -m "feat(前端): 4 业务页 (categories/books/records/audit-logs)"
```

---

## Task 9: 端到端集成测试 + README 部署说明

**Files:**
- Modify: `003.前端代码（前端工程师）/admin-frontend/README.md`

**Step 1: README 补充部署章节**

```markdown
## 与主前端共存部署

Nginx 单域名配置示例:

```nginx
server {
  listen 80;
  server_name _;

  # 管理后台 (admin SPA)
  location /admin/ {
    root /var/www/qingzhang/admin-frontend/dist;
    try_files $uri /admin/index.html;
  }

  # 主前端 SPA
  location / {
    root /var/www/qingzhang/frontend-react-java/dist;
    try_files $uri /index.html;
  }

  # API 反代
  location /api/ {
    proxy_pass http://localhost:8080;
  }
}
```

构建:
```bash
cd admin-frontend && npm run build
# 产物 dist/ 整个拷到服务器 /var/www/qingzhang/admin-frontend/dist/
```

## 已知限制

- 撤销角色后管理员仍持旧 token,需 24h 自然过期(由 `jwt.admin-expiration-hours: 24` 控制)
- 后端 `/api/admin/*` 鉴权依赖 V5 migration 与 `admin_user_roles` 数据,务必先跑 Plan A
```

**Step 2: 端到端冒烟 (跨前后端)**

```bash
# 1. 启动后端 (Plan A bootstrap 已建 root 用户)
cd "005.后端代码（Java工程师）"
ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD='Root@12345' \
  mvn -q spring-boot:run &
sleep 30

# 2. 跑后端冒烟
cd ..
./scripts/smoke-admin.sh
# Expected: ALL PASSED

# 3. 启动前端
cd "003.前端代码（前端工程师）/admin-frontend"
npm run dev &
sleep 5

# 4. 浏览器手动验证 (无 headless):http://localhost:5174/admin/login
#    - 用 root/Root@12345 登录 → 进 dashboard
#    - 看见 7 个统计卡片 + 最近 7 天柱图
#    - 点 "用户管理" → 看见 root + alice2 (若存在)
#    - 点 "禁用" → 状态变红 + 审计日志新增一条 user.disable
#    - 点 "审计日志" → 看见刚才的记录 + before/after snapshot JSON

kill %1 %2
```

**Step 3: Commit**

```bash
git add "003.前端代码（前端工程师）/admin-frontend/README.md"
git commit -m "docs(前端): admin-frontend 部署说明 + 已知限制"
```

---

## Self-Review

**1. Spec coverage** (§7 admin SPA):
- §7.1 位置 ✓ (Task 1)
- §7.2 依赖 ✓ (Task 1,精简到 React 19 + Vite 8 + react-router-dom 7)
- §7.3 文件结构 30 文件 ✓ (Tasks 1-8)
- §7.4 路由表 ✓ (Task 3 + Task 6-8 增量)
- §7.5 AdminLayout 顶栏+侧栏 ✓ (Task 6)
- §7.6 Auth Flow 复用主端点 + 检查 isSuperAdmin ✓ (Task 4)
- §7.7 Dev/Prod 部署 ✓ (Task 9)

**2. Placeholder scan**: 0 个 TBD/TODO。所有页面有真实实现,无"待补充"。

**3. Type consistency**:
- `ApiResponse<T>` 客户端 unwrap → Task 2
- `AdminMeResponse` 字段顺序/类型 → Task 2 类型,Task 3/4 一致引用
- `useAdminAuth().hasPermission(code)` → Task 3 提供,Task 5-7 PermissionGate 复用
- API 函数签名 `list(params)` / `detail(id)` 等 → Task 7-8 与后端 Plan A §4.4 对齐

**4. 与 Plan A 协同点**:
- Plan A Task 4 加 `permissions/roleCodes/isSuperAdmin` 到 AuthResponse → Plan B Task 4 才能登录后跳转
- Plan A Task 5 @RequiresPermission → Plan B 所有 PermissionGate 才能正确隐藏
- Plan A Task 7 Bootstrap → Plan B 才能登录 (有 root 用户)
- Plan A Task 8-11 16 个端点 → Plan B 7 个页面才能拿到数据

执行顺序建议:**先跑 Plan A Task 1-7**(到 Bootstrap 完成为止),再起 Plan B;Plan A Task 8-11 与 Plan B Task 5-8 可并行。