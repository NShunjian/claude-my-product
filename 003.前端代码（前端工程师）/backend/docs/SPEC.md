# 轻账 (QingZhang) 后端登录/注册功能 —— 设计规格

> 文档状态：待审阅  
> 撰写日期：2026-08-26  
> 适用产品版本：V1.0.1（用户认证增量）  
> 配套前端：React 19 + TypeScript + Zustand（[003.前端代码（前端工程师）/frontend/qingzhang/](../../../../qingzhang/)）  
> 配套数据库：MySQL 9.x（[004.数据库脚本/](../../../../004.数据库脚本/)）

---

## 一、背景与目标

### 1.1 背景

PRD V1.0.1 引入了用户身份体系。前端已基于 Dexie / IndexedDB 实现纯本地登录，仅作"入口控制"。本次为后续 V1.1（共享账本、云同步）铺路，新增**真实后端 API**，将身份校验从本地迁移到服务端。

### 1.2 目标

- 提供 `/api/auth/register`、`/api/auth/login`、`/api/auth/me`、`/api/auth/logout` 四个 HTTP 接口
- 密码使用 bcrypt 安全哈希存储
- 鉴权基于 JWT（HS256，TTL 7 天）
- 前端可在保留 Zustand store 的前提下，平滑切换为调用本后端

### 1.3 不做的事（YAGNI）

- 手机号 / 邮箱注册、第三方登录、找回密码（V1.1 再考虑）
- 多端会话管理、refresh token（V1.1）
- RBAC 权限分级（V1.1 共享账本时再设计）
- Redis 缓存、消息队列等基础设施（过早优化）

---

## 二、技术栈

| 层 | 选型 | 版本 | 用途 |
|---|------|------|------|
| 运行时 | Node.js | 22 LTS | |
| 语言 | TypeScript | ^5.6 | 与前端类型对齐 |
| HTTP 框架 | Express | ^5.0 | 路由 + 中间件 |
| 密码哈希 | bcrypt | ^5.1 | cost factor 12 |
| 鉴权 | jsonwebtoken | ^9.0 | HS256 |
| 入参校验 | zod | ^3.23 | Schema 校验 |
| 安全 | helmet / cors / express-rate-limit | 最新 | 加固 HTTP 头、CORS、限流 |
| MySQL 驱动 | mysql2/promise | ^3.11 | 连接池 |
| 配置 | dotenv | ^16.4 | .env 加载 |
| 开发态 | tsx / nodemon | 最新 | 热重载 |

---

## 三、目录结构

```
003.前端代码（前端工程师）/backend/
├── package.json
├── tsconfig.json
├── .env.example
├── .gitignore
├── README.md
├── docs/
│   └── SPEC.md               ← 本文档
└── src/
    ├── index.ts              ← 入口
    ├── config/
    │   └── env.ts            ← 环境变量加载 + zod 校验
    ├── db/
    │   └── pool.ts           ← MySQL 连接池
    ├── middleware/
    │   ├── auth.ts           ← JWT 鉴权
    │   ├── error.ts          ← 统一错误处理
    │   └── rate-limit.ts     ← 登录/注册限流
    ├── routes/
    │   └── auth.routes.ts
    ├── controllers/
    │   └── auth.controller.ts
    ├── services/
    │   └── auth.service.ts
    ├── utils/
    │   ├── hash.ts
    │   └── jwt.ts
    ├── schemas/
    │   └── auth.schema.ts
    └── types/
        └── index.ts          ← User / AuthRequest 等
```

---

## 四、接口设计

### 4.1 POST /api/auth/register

**入参**：

```json
{
  "username": "string (2~20 chars)",
  "password": "string (6~32 chars)"
}
```

**响应 201**：

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 2,
    "uuid": "550e8400-e29b-41d4-a716-446655440000",
    "username": "demo",
    "displayName": null,
    "createdAt": "2026-08-26T17:36:27.000Z"
  }
}
```

**错误**：

| HTTP | 场景 |
|------|------|
| 400 | zod 校验失败（用户名 / 密码长度不符） |
| 409 | 用户名已被注册（DB UNIQUE 冲突） |
| 429 | 1 分钟内 > 10 次 |

### 4.2 POST /api/auth/login

**入参**：

```json
{ "username": "string", "password": "string" }
```

**响应 200**：同 4.1

**错误**：

| HTTP | 场景 |
|------|------|
| 401 | 用户不存在 |
| 401 | 密码错误（统一文案"用户名或密码错误"防枚举） |
| 429 | 限流 |

### 4.3 GET /api/auth/me

**请求头**：`Authorization: Bearer <token>`

**响应 200**：`{ user }`

**错误**：

| HTTP | 场景 |
|------|------|
| 401 | token 缺失 / 无效 / 过期 |

### 4.4 POST /api/auth/logout

**请求头**：Bearer token

**响应 200**：`{ ok: true }`

> 注：JWT 是无状态的；logout 仅在前端清空 token。如未来需要服务端撤销，引入 Redis 黑名单即可。

---

## 五、数据流（以 register 为例）

```
Client
  │  POST /api/auth/register { username, password }
  ▼
Express
  │  helmet, cors, rate-limit, body-parser
  ▼
auth.routes.ts
  │  router.post('/register', validate(registerSchema), authController.register)
  ▼
auth.controller.ts
  │  const { username, password } = req.body
  │  → authService.register(username, password)
  ▼
auth.service.ts
  │  1. 查重 SELECT * FROM users WHERE username = ?
  │  2. 哈希 bcrypt.hash(password, 12)
  │  3. 写库 INSERT INTO users (uuid, username, password_hash, ...)
  │  4. 返回 { user, token }
  ▼
utils/jwt.ts
  │  jwt.sign({ sub: user.id, uuid }, JWT_SECRET, { expiresIn: '7d' })
  ▼
Response
  201 { token, user }
```

---

## 六、数据模型

复用已有 `users` 表（[004.数据库脚本/01_schema_qingzhang.sql](../../../../004.数据库脚本/01_schema_qingzhang.sql)）：

| 字段 | 类型 | 用途 |
|------|------|------|
| `id` | BIGINT UNSIGNED PK | 服务端主键 |
| `uuid` | CHAR(36) UNIQUE | 对前端 `User.id` |
| `username` | VARCHAR(20) UNIQUE | 登录名 |
| `password_hash` | VARCHAR(255) | bcrypt 哈希（升级 60 → 60~255） |
| `salt` | VARCHAR(64) | 不再使用，保留兼容 |
| `display_name` | VARCHAR(50) NULL | 昵称 |
| `status` | TINYINT | 1=启用 0=禁用 |
| `last_login_at` | DATETIME(3) | 登录后回填 |
| `created_at` / `updated_at` | DATETIME(3) | 时间戳 |

> **不改动表结构**：bcrypt 哈希长度（60）< `VARCHAR(255)` 限制，可直接复用。`salt` 列保留，前端 V1.0.1 的 SHA-256+salt 暂未用到，列存在但不消费。

---

## 七、安全设计

| 维度 | 措施 |
|------|------|
| 密码 | bcrypt cost=12（约 250ms/次） |
| Token | JWT HS256，TTL 7 天，secret ≥ 32 字节随机串 |
| 登录枚举 | 统一文案"用户名或密码错误"，不区分用户不存在 / 密码错 |
| 限流 | `/login` `/register` 1 分钟 / 同 IP 10 次（express-rate-limit） |
| HTTP 头 | helmet 默认配置 |
| CORS | 仅放行 `http://localhost:5173`（dev）+ 后续生产域名 |
| SQL 注入 | mysql2 预编译语句（? 占位符） |
| 日志 | 不打印 password / token；统一 `operation_logs` 写库 |
| ENV | JWT_SECRET 写入 `.env`，不入库不入版本 |

---

## 八、错误处理

**统一错误响应格式**：

```json
{ "error": { "code": "USERNAME_TAKEN", "message": "该用户名已被注册" } }
```

**错误码常量**（`src/constants/errors.ts`）：

| code | HTTP |
|------|------|
| `INVALID_INPUT` | 400 |
| `USERNAME_TAKEN` | 409 |
| `INVALID_CREDENTIALS` | 401 |
| `MISSING_TOKEN` | 401 |
| `INVALID_TOKEN` | 401 |
| `RATE_LIMIT` | 429 |
| `INTERNAL` | 500 |

由 `middleware/error.ts` 统一捕获并格式化，避免每个 controller 重复 `try/catch`。

---

## 九、配置（.env.example）

```env
# 服务
PORT=4000
NODE_ENV=development

# MySQL
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=123456
DB_NAME=qingzhang

# JWT
JWT_SECRET=please-change-me-to-a-32-byte-random-string-xxxxx
JWT_EXPIRES_IN=7d

# CORS
CORS_ORIGIN=http://localhost:5173

# bcrypt
BCRYPT_COST=12
```

---

## 十、测试策略

| 层级 | 工具 | 范围 |
|------|------|------|
| 单元 | vitest | `auth.service.ts`、`utils/hash.ts`、`utils/jwt.ts` |
| 集成 | vitest + supertest | `routes/auth.routes.ts`：4 个端点的正常/异常路径 |
| 端到端 | curl 脚本 | 注册 → 登录 → /me → 退出 全流程 |

数据库层使用 Docker 中的 `qingzhang` 实例作为真实测试库（已就绪）。

---

## 十一、交付清单（实施完成后）

- [ ] `package.json` / `tsconfig.json` / `.env.example` / `.gitignore`
- [ ] 上述目录树中所有源文件
- [ ] `README.md`：启动方式、接口 curl 示例、环境变量说明
- [ ] SPEC 已实现检查表

---

## 十二、与前端的契约

前端 `useAuthStore` 改造（如选择本期接入）需做：

1. `register/login` 改为 `fetch('/api/auth/register')` + `fetch('/api/auth/login')`
2. 登录态改为持久化 `{ token, user }`，并加 `Authorization` 头
3. 删除对 Dexie `users` 表的读写
4. 路由守卫逻辑保留不变

> 本期**只实现后端**，前端接入另起一 PR 评审。

---

## 十三、开放问题（实施前需确认）

| # | 问题 | 默认决定 |
|---|------|---------|
| Q1 | 是否同步改造前端？ | **否**（仅后端） |
| Q2 | token 存哪里？ | 前端 `localStorage`（保留 Zustand persist） |
| Q3 | 接口前缀 | `/api/auth/*` |
| Q4 | JWT issuer | 不设置（V1.1 再说） |

---

> 📌 下一步：审阅通过 → 调用 writing-plans 出实施计划 → 落地代码