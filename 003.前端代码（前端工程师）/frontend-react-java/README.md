# 轻账 · 前端 (React + Vite) — Java 版

React 19 + TypeScript + Vite + Tailwind v4 前端单页应用,对接 **Java 后端**(`005.后端代码(Java工程师)/`,默认 http://localhost:4001)。

> 本目录与 `frontend-react/` 同源,经过裁剪:**移除了所有对旧 Node/Express 后端的引用、集成测试与说明**;端口与 BASE 默认指向 Java 服务。运行时通过 `VITE_API_BASE` 覆盖。

## Prerequisites

- Node.js ≥ 22
- Java 后端已起在 **4001** 端口(参见 `../../005.后端代码（Java工程师）/README.md`),MySQL `qingzhang` 数据库可用
- 现代浏览器

## Quick Start

```bash
cd frontend-react-java
npm install   # 首次
npm run dev   # http://localhost:5173
```

浏览器访问 http://localhost:5173/ → 自动跳到 `/login`。注册/登录调 Java 后端的 `/api/auth/*`,成功后凭 JWT 访问受保护页面。

## Scripts

| command           | purpose                            |
|-------------------|------------------------------------|
| `npm run dev`     | Vite dev server (HMR, port 5173)   |
| `npm run build`   | TypeScript 检查 + Vite 生产构建     |
| `npm run preview` | 预览 `dist/` 产物                  |
| `npm run lint`    | oxlint 检查                        |
| `npm run test`    | vitest 单元/E2E                    |

## 环境变量

| name             | default                  | 说明                                |
|------------------|--------------------------|------------------------------------|
| `VITE_API_BASE`  | `http://localhost:4001`  | 后端基础地址,所有请求前缀(默认指 Java) |

在 `frontend-react-java/.env.local` 写 `VITE_API_BASE=https://api.example.com` 覆盖。

## 调用的后端端点

| 方法  | 路径                | 用途                          |
|-------|---------------------|-------------------------------|
| POST  | `/api/auth/register`| 注册(用户名+密码)→ token      |
| POST  | `/api/auth/login`   | 登录 → token                  |
| POST  | `/api/auth/logout`  | 登出(无状态)                  |
| GET   | `/api/auth/me`      | `Authorization: Bearer …` 拉当前用户 |

> **注意**:`src/lib/api.ts` 当前按 `{user, token}` / `{error:{code,message}}` 解析后端响应 — 见下一节。

## 后续要做(下一轮)

- **响应合同对齐**:Java 后端 `ApiResponse<T>` 是 `{code, message, data}` 包装;现有前端按 Node 的扁平 `{user,token}` 读。要么 Java 端给 auth 返兼容形状,要么前端切到读 `data.user` / `data.token`。
- 7 组业务接口(auth/users/books/accounts/categories/records/reports)逐一对接到 Java Controller。

## 目录结构

```
src/
├── main.tsx               入口:包 AuthProvider + BrowserRouter
├── App.tsx                路由定义
├── index.css              Tailwind v4 + @theme 设计 token
├── vite-env.d.ts          ImportMetaEnv 类型扩展
├── lib/
│   └── api.ts             fetch 封装 + ApiError + JWT 注入
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

视觉风格(颜色 / 间距 / 字号 / 圆角 / 字体)从静态原型 `../frontend/pages/01-login.html` 1:1 移植到 `src/index.css` 的 `@theme` 块(Tailwind v4 语法)。后续如果加新页面,继续用 `bg-primary` / `p-md` / `text-display-lg` 等工具类,保持视觉一致。
