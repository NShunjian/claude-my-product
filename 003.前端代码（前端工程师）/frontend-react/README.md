# 轻账 · 前端 (React + Vite)

React 19 + TypeScript 6 + Vite 8 + Tailwind v4 前端单页应用，对接 [`../backend/`](../backend/) 的 4 个 auth 端点（register / login / me / logout）。本目录目前实现了登录与受保护主页：注册 → 登录 → 调 `/me` 显示当前用户。

## Prerequisites

- Node.js ≥ 22
- 后端已经在 4000 端口运行（`../backend/`），MySQL `qingzhang` 数据库可用

## Quick Start

两个终端：

```bash
# 终端 1：后端
cd ../backend
npm install   # 首次
npm run dev   # 监听 http://localhost:4000

# 终端 2：前端
npm install   # 首次
npm run dev   # 监听 http://localhost:5173
```

浏览器访问 http://localhost:5173/ → 自动跳到 `/login`。切换「登录 / 注册」Tab，注册一个新用户，自动跳到 Dashboard 看 `/me` 返回的用户信息。

## Scripts

| command         | purpose                          |
|-----------------|----------------------------------|
| `npm run dev`   | Vite dev server (HMR, port 5173) |
| `npm run build` | TypeScript 检查 + Vite 生产构建  |
| `npm run preview` | 预览 `dist/` 产物              |
| `npm run lint`  | oxlint 检查                      |

## 环境变量

| name             | default                   | 说明                          |
|------------------|---------------------------|-------------------------------|
| `VITE_API_BASE`  | `http://localhost:4000`   | 后端地址，前端所有请求的前缀 |

在 `frontend-react/.env.local` 里写 `VITE_API_BASE=https://api.example.com` 即可覆盖。

## 调用的后端端点

| 方法  | 路径                | 用途                          |
|-------|---------------------|-------------------------------|
| POST  | `/api/auth/register`| 注册（用户名+密码）→ 返回 token |
| POST  | `/api/auth/login`   | 登录 → 返回 token              |
| GET   | `/api/auth/me`      | 用 `Authorization: Bearer <token>` 头拉当前用户 |

后端响应统一为 `{user, token}` 或 `{user}`，错误统一为 `{error:{code, message}}`。前端在 `src/lib/api.ts` 把后者解析为 `ApiError`，Login 页面直接显示 `error.message`（已是中文）。

## 目录结构

```
src/
├── main.tsx               入口：包 AuthProvider + BrowserRouter
├── App.tsx                路由定义
├── index.css              Tailwind v4 + @theme 设计 token
├── vite-env.d.ts          ImportMetaEnv 类型扩展
├── lib/
│   └── api.ts             fetch 封装 + ApiError
├── api/
│   └── auth.ts            register/login/me 类型化包装
├── auth/
│   ├── AuthContext.tsx    token + user 状态、localStorage 持久化
│   └── ProtectedRoute.tsx 未登录跳转 /login
└── pages/
    ├── Login.tsx          登录/注册切换表单
    └── Dashboard.tsx      /me 用户信息卡片 + 退出登录
```

## 设计 Token

视觉风格（颜色 / 间距 / 字号 / 圆角 / 字体）从静态原型 [`../frontend/pages/01-login.html`](../frontend/pages/01-login.html) 1:1 移植到 `src/index.css` 的 `@theme` 块（Tailwind v4 语法）。后续如果加新页面，继续用 `bg-primary` / `p-md` / `text-display-lg` 等生成的工具类，保持视觉一致。