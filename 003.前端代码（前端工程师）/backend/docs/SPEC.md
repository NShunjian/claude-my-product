# 轻账 (QingZhang) 后端 —— 设计规格

> 文档状态：待审阅  
> 撰写日期：2026-08-26（业务 API 章节 2026-08-27 追加）  
> 适用产品版本：V1.0.1（用户认证 + 业务 API 增量）  
> 配套前端：React 19 + TypeScript + Zustand（[003.前端代码（前端工程师）/frontend/qingzhang/](../../../../qingzhang/)）  
> 配套数据库：MySQL 9.x（[004.数据库脚本/](../../../../004.数据库脚本/)）

---

## 一、背景与目标

### 1.1 背景

PRD V1.0.1 引入了用户身份体系。前端已基于 Dexie / IndexedDB 实现纯本地登录，仅作"入口控制"。本次为后续 V1.1（共享账本、云同步）铺路，新增**真实后端 API**，将身份校验从本地迁移到服务端。

V1.0.1 业务 API 增量：在身份基础上，补齐**分类 / 账户 / 流水 / 报表 / 用户资料**五个域的 HTTP 接口，前端可平滑从 mock（`src/data/*.ts`）切换到真实服务。

### 1.2 目标

- 提供 `/api/auth/{register,login,me,logout}` 四个 HTTP 接口
- 提供 `/api/categories`、`/api/accounts`、`/api/records`、`/api/reports/{monthly,yearly}`、`/api/users/me*` 业务 API
- 密码使用 bcrypt 安全哈希存储
- 鉴权基于 JWT（HS256，TTL 7 天）
- 新用户注册自动创建 1 个账本 + 5 个默认账户（微信支付/支付宝/现金/银行卡/信用卡）

### 1.3 不做的事（YAGNI）

- 手机号 / 邮箱注册、第三方登录、找回密码（V1.1 再考虑）
- 多端会话管理、refresh token（V1.1）
- RBAC 权限分级（V1.1 共享账本时再设计）
- ✅ 头像上传（V1.1, 2026-08 已落地，base64 inline 实现，见 §8 PATCH /api/users/me）
- Redis 缓存、消息队列等基础设施（过早优化）
- 多币种、预算、共享账本（V2.0）

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
├── src/
│   ├── index.ts              ← 入口
│   ├── config/
│   │   └── env.ts            ← 环境变量加载 + zod 校验
│   ├── db/
│   │   ├── pool.ts           ← MySQL 连接池
│   │   └── sql/              ← 初始化 SQL（与 DBA 目录同步）
│   │       ├── 01_schema_qingzhang.sql
│   │       └── 02_seed_qingzhang.sql
│   ├── middleware/
│   │   ├── auth.ts           ← JWT 鉴权
│   │   ├── error.ts          ← 统一错误处理
│   │   ├── not-found.ts
│   │   └── rate-limit.ts     ← 登录/注册限流
│   ├── constants/
│   │   └── errors.ts         ← ErrorCode 常量
│   ├── routes/
│   │   ├── auth.routes.ts
│   │   ├── categories.routes.ts
│   │   ├── accounts.routes.ts
│   │   ├── records.routes.ts
│   │   ├── reports.routes.ts
│   │   └── users.routes.ts
│   ├── controllers/
│   │   ├── auth.controller.ts
│   │   ├── categories.controller.ts
│   │   ├── accounts.controller.ts
│   │   ├── records.controller.ts
│   │   ├── reports.controller.ts
│   │   └── users.controller.ts
│   ├── services/
│   │   ├── auth.service.ts
│   │   ├── categories.service.ts
│   │   ├── accounts.service.ts
│   │   ├── records.service.ts
│   │   ├── reports.service.ts
│   │   └── users.service.ts
│   ├── utils/
│   │   ├── hash.ts
│   │   └── jwt.ts
│   ├── schemas/              ← zod schemas
│   │   ├── auth.schema.ts
│   │   ├── categories.schema.ts
│   │   ├── accounts.schema.ts
│   │   ├── records.schema.ts
│   │   ├── reports.schema.ts
│   │   └── users.schema.ts
│   ├── types/
│   │   └── index.ts          ← Category / Account / Record / PageMeta 等
│   └── scripts/              ← DB 初始化脚本
│       ├── schema.ts
│       ├── seed.ts
│       └── init.ts
└── tests/                    ← vitest + supertest
```

---

## 四、接口设计 — 鉴权

### 4.1 POST /api/auth/register

**入参**：

```json
{
  "username": "string (2~20 chars，字母/数字/中文/下划线)",
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

**副作用**：注册成功后自动创建 1 个账本（`个人账本`，`type=personal`，`is_default=1`） + 5 个默认账户：

| 名称 | 类型 | 是否默认 | 排序 |
|------|------|---------|------|
| 微信支付 | wallet | ✅ | 0 |
| 支付宝 | wallet | — | 1 |
| 现金 | cash | — | 2 |
| 银行卡 | debit | — | 3 |
| 信用卡 | credit | — | 4 |

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

**响应 200**：同 4.1（user 字段不包含 `password_hash`）。

**错误**：

| HTTP | 场景 |
|------|------|
| 401 | 用户不存在 |
| 401 | 密码错误（统一文案"用户名或密码错误"防枚举） |
| 429 | 限流 |

### 4.3 GET /api/auth/me

**请求头**：`Authorization: Bearer <token>`

**响应 200**：`{ user }`

**User 响应字段**：

```ts
interface User {
  id: number                       // 物理主键
  uuid: string                     // 业务主键（前端统一使用此 ID）
  username: string
  displayName: string | null       // 昵称（用户编辑资料设置）
  avatar: string | null            // 头像 URL 或 dataURL（V1.1 支持 base64 内联图，详见 §8 PATCH /api/users/me）
  gender: 'male' | 'female' | 'other' | null
  age: number | null               // 0~120
  createdAt: string                // ISO
}
```

> 完整字段由 `register` / `login` / `me` / `getCurrentUser` 共同返回；
> 任何修改 profile 的 API（`PATCH /api/users/me`）后调用本接口会反映新值。

**错误**：

| HTTP | 场景 |
|------|------|
| 401 | token 缺失 / 无效 / 过期 |

### 4.4 POST /api/auth/logout

**请求头**：Bearer token

**响应 200**：`{ ok: true }`

> 注：JWT 是无状态的；logout 仅在前端清空 token。如未来需要服务端撤销，引入 Redis 黑名单即可。

---

## 五、接口设计 — 业务 API

### 5.1 分类（系统预设，GET 无需鉴权）

| Method | Path | Auth | 说明 |
|--------|------|------|------|
| GET | `/api/categories` | ❌ | 查询参数 `?type=expense\|income`（可省略=返回全部） |

**Category 响应**：

```ts
interface Category {
  id: string              // uuid，如 'expense-餐饮'
  type: 'expense' | 'income'
  name: string            // '餐饮'
  icon: string            // emoji（前端可按需 Material Symbols 映射）
  color: string           // '#RRGGBB'
  sortOrder: number
}
```

**示例**：

```bash
GET /api/categories?type=expense
# → 200 { items: [{ id: 'expense-餐饮', type: 'expense', name: '餐饮', icon: '🍔', color: '#FF6B6B', sortOrder: 0 }, ...] }
```

---

### 5.2 账户（per-user，全部需鉴权）

| Method | Path | Auth | 说明 |
|--------|------|------|------|
| GET | `/api/accounts` | ✅ | 当前用户账户列表（含 `v_account_balance` 计算的实时余额） |
| POST | `/api/accounts` | ✅ | 创建账户 |
| PATCH | `/api/accounts/:id` | ✅ | 更新账户（名称/余额/icon/isDefault） |
| DELETE | `/api/accounts/:id` | ✅ | 软删除（设 `deleted_at`），校验无未删除流水 |

**Account 响应**：

```ts
interface Account {
  id: string                      // uuid
  name: string
  type: 'cash' | 'debit' | 'credit' | 'wallet' | 'investment' | 'other'
  icon: string
  initialBalance: number          // 创建时余额
  balance: number                 // 实时计算（v_account_balance 视图）
  currency: string                // 'CNY'
  isDefault: boolean              // 默认账户（每个用户仅一个）
  sortOrder: number
  note: string | null
  createdAt: string               // ISO
}
```

**POST /api/accounts 入参**：

```json
{
  "name": "string (1~20)",
  "type": "cash|debit|credit|wallet|investment|other",
  "icon": "string (1~8)",
  "initialBalance": 0,
  "currency": "CNY",
  "isDefault": false,
  "sortOrder": 0,
  "note": "string | null"
}
```

**PATCH /api/accounts/:id 入参**：同 POST 字段均可选；修改 `initialBalance` 时自动调整 `balance`（按当前已有流水差额补偿）。

**DELETE /api/accounts/:id**：

| HTTP | 场景 |
|------|------|
| 400 | 该账户仍有未删除流水 |
| 404 | 账户不存在或非本人 |

**响应包装约定**（与 §5.1 / §5.3 一致）：

| Method | 响应体 |
|--------|--------|
| GET    | `{ items: Account[] }` |
| POST   | 201 `{ account: Account }` |
| PATCH  | `{ account: Account }` |
| DELETE | 204 空 |

---

### 5.3 流水（records，全部需鉴权）

| Method | Path | Auth | 说明 |
|--------|------|------|------|
| GET | `/api/records` | ✅ | 查询参数：`?month=YYYY-MM` 或 `?from=YYYY-MM-DD&to=YYYY-MM-DD`；附加 `type`、`categoryId`、`accountId` |
| POST | `/api/records` | ✅ | 创建流水（expense/income/transfer） |
| PATCH | `/api/records/:id` | ✅ | 更新流水 |
| DELETE | `/api/records/:id` | ✅ | 软删除 |

**Record 响应**：

```ts
interface Record {
  id: string
  type: 'expense' | 'income' | 'transfer'
  categoryId: string | null       // transfer 时为 null
  accountId: string
  toAccountId: string | null     // 仅 transfer
  amount: number                 // > 0
  currency: string               // 'CNY'
  note: string | null
  recordDate: string             // 'YYYY-MM-DD'
  source: 'manual' | 'import' | 'ocr' | 'auto' | 'sync'
  clientId: string | null        // 离线去重 ID
  createdAt: string              // ISO
  updatedAt: string              // ISO
}
```

**POST /api/records 入参**（discriminated union by `type`）：

```ts
// expense
{ type: 'expense', categoryId: 'string', accountId: 'string', amount: number, recordDate: 'YYYY-MM-DD', note?: string, clientId?: string }
// income
{ type: 'income',  categoryId: 'string', accountId: 'string', amount: number, recordDate: 'YYYY-MM-DD', note?: string, clientId?: string }
// transfer
{ type: 'transfer', accountId: 'string', toAccountId: 'string', amount: number, recordDate: 'YYYY-MM-DD', note?: string, clientId?: string }
```

**幂等性**：`client_id` 在用户维度 UNIQUE；同 `clientId` 重复 POST 返回原 record（不创建新行）。

**响应包装约定**（与 §5.2 一致）：

| Method | 响应体 |
|--------|--------|
| GET    | `{ items: Record[] }` |
| POST   | 201 `{ record: Record }` |
| PATCH  | `{ record: Record }` |
| DELETE | 204 空 |

---

### 5.4 报表（聚合查询，全部需鉴权）

| Method | Path | Auth | 说明 |
|--------|------|------|------|
| GET | `/api/reports/monthly` | ✅ | 查询参数 `?month=YYYY-MM`（默认当前月） |
| GET | `/api/reports/yearly` | ✅ | 查询参数 `?year=YYYY`（默认当前年） |

**月度响应**：

```ts
{
  month: 'YYYY-MM'
  totalIncome: number
  totalExpense: number
  netSavings: number              // totalIncome - totalExpense
  lastMonth: { totalIncome, totalExpense, netSavings } | null
  incomeByCategory:  { categoryId, name, icon, color, total }[]   // 降序
  expenseByCategory: { categoryId, name, icon, color, total }[]   // 降序
  dailyData: { day: 1-31, income: number, expense: number }[]
}
```

**年度响应**：

```ts
{
  year: number
  totalIncome: number
  totalExpense: number
  netSavings: number
  monthlyData: { month: 1-12, income: number, expense: number }[]
  expenseByCategory: { categoryId, name, icon, color, total }[]   // 全年汇总降序
}
```

---

### 5.5 用户资料（全部需鉴权）

| Method | Path | Auth | 说明 |
|--------|------|------|------|
| GET | `/api/auth/me` | ✅ | （鉴权 §4.3） |
| PATCH | `/api/users/me` | ✅ | 更新 displayName / avatar / gender / age |
| POST | `/api/users/me/password` | ✅ | 修改密码（验旧 + 新密码规则） |

**PATCH /api/users/me 入参**：

```json
{
  "displayName": "string (1~50) | null",   // 可选
  "avatar":      "https://... | data:image/(png|jpeg|webp);base64,... | null",     // 可选；URL 或 base64 dataURL（解码后 ≤ 30KB；V1.1 起支持 dataURL）
  "gender":      "male|female|other | null",
  "age":         0..120 | null
}
```

> 至少需提供一个字段；其他字段保持原值。

**POST /api/users/me/password 入参**：

```json
{ "oldPassword": "string", "newPassword": "string (6~32)" }
```

**错误**：

| HTTP | 场景 |
|------|------|
| 400 | zod 校验失败 |
| 401 | 旧密码错误（`INVALID_CREDENTIALS`） |

---

## 六、数据流（以 register 为例）

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
  │  4. bootstrapNewUser() → INSERT INTO books + 5 × INSERT INTO accounts
  │  5. 返回 { user, token }
  ▼
utils/jwt.ts
  │  jwt.sign({ sub: user.id, uuid, username }, JWT_SECRET, { expiresIn: '7d' })
  ▼
Response
  201 { token, user }
```

业务模块（categories/accounts/records/reports/users）数据流与 auth 一致：

```
Client → routes/<m>.routes.ts → controllers/<m>.controller.ts
  → services/<m>.service.ts（执行业务 + SQL）
  → utils/jwt.ts (无状态校验在 middleware/auth.ts)
  → Response
```

---

## 七、数据模型

复用 [004.数据库脚本/01_schema_qingzhang.sql](../../../../004.数据库脚本/01_schema_qingzhang.sql) 的 10 张表 + 2 视图。关键表：

| 表 | 关键字段 | 用途 |
|------|------|------|
| `users` | `id`, `uuid`, `username`, `password_hash`, `display_name`, `avatar`, `gender ENUM('male','female','other')`, `age TINYINT UNSIGNED`, `status`, `last_login_at` | 账号 |
| `books` | `id`, `uuid`, `owner_id`, `name`, `type`, `currency`, `is_default` | 账本（V1 仅个人账本） |
| `accounts` | `id`, `uuid`, `user_id`, `book_id`, `name`, `type`, `initial_balance`, `current_balance`, `is_default`, `sort_order` | 账户 |
| `categories` | `id`, `uuid`, `user_id NULL`, `type`, `name`, `icon`, `color`, `sort_order` | 分类（`user_id=NULL` 表示系统预设） |
| `records` | `id`, `uuid`, `user_id`, `book_id`, `category_id NULL`, `account_id`, `to_account_id NULL`, `type`, `amount`, `currency`, `note`, `record_date DATE`, `source`, `client_id` | 流水 |
| `record_attachments` | `record_id`, `file_url`, ... | 附件（V1.1 再消费） |
| `operation_logs` | `user_id`, `action`, `target_type`, `target_id`, `meta JSON` | 审计日志 |
| `idempotency_keys` | `user_id`, `scope`, `key`, `record_id`, `expires_at` | 幂等去重（本期未启用） |
| `v_account_balance` | VIEW | 账户余额实时聚合 |
| `v_monthly_summary` | VIEW | 月度收支聚合 |

> **views 增强**：本版本在 `v_account_balance` 中暴露 `icon / currency / note / created_at`，便于前端一次取齐账户信息。

---

## 八、安全设计

| 维度 | 措施 |
|------|------|
| 密码 | bcrypt cost=12（约 250ms/次） |
| Token | JWT HS256，TTL 7 天，secret ≥ 32 字节随机串 |
| 登录枚举 | 统一文案"用户名或密码错误"，不区分用户不存在 / 密码错 |
| 限流 | `/api/auth/login` `/api/auth/register` 1 分钟 / 同 IP 10 次（express-rate-limit） |
| 数据隔离 | 所有业务查询必须按 `user_id` 过滤（`req.user.sub`），不允许跨用户访问 |
| HTTP 头 | helmet 默认配置 |
| CORS | 仅放行 `CORS_ORIGIN`（dev = `http://localhost:5173`） |
| SQL 注入 | mysql2 预编译语句（? 占位符） |
| 日志 | 不打印 password / token；统一 `operation_logs` 写库 |
| ENV | JWT_SECRET 写入 `.env`，不入库不入版本 |

---

## 九、错误处理

**统一错误响应格式**：

```json
{ "error": { "code": "USERNAME_TAKEN", "message": "该用户名已被注册" } }
```

**错误码常量**（`src/constants/errors.ts`）：

| code | HTTP | 含义 |
|------|------|------|
| `INVALID_INPUT` | 400 | zod 校验失败 |
| `INVALID_CREDENTIALS` | 401 | 旧密码错误 / 登录失败 |
| `MISSING_TOKEN` | 401 | 未携带 token |
| `INVALID_TOKEN` | 401 | token 无效 / 过期 |
| `FORBIDDEN` | 403 | 越权访问 |
| `NOT_FOUND` | 404 | 资源不存在或非本人 |
| `CONFLICT` | 409 | 资源冲突（如唯一键） |
| `USERNAME_TAKEN` | 409 | 用户名已被注册 |
| `WEAK_PASSWORD` | 400 | 密码强度不足 |
| `RATE_LIMIT` | 429 | 限流 |
| `INTERNAL` | 500 | 服务端异常 |

由 `middleware/error.ts` 统一捕获并格式化，避免每个 controller 重复 `try/catch`。

---

## 十、配置（.env.example）

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

**新增 npm scripts**：

```json
{
  "db:init":   "tsx --env-file=.env src/scripts/init.ts",
  "db:schema": "tsx --env-file=.env src/scripts/schema.ts",
  "db:seed":   "tsx --env-file=.env src/scripts/seed.ts"
}
```

`db:schema` 跑 `src/db/sql/01_schema_qingzhang.sql`（drop + create，含视图）；`db:seed` 跑 `02_seed_qingzhang.sql`（含 demo 用户密码 bcrypt 哈希）。**不在 backend 启动时自动跑**，完全手动触发避免多实例 race condition。

---

## 十一、测试策略

| 层级 | 工具 | 范围 |
|------|------|------|
| 单元 | vitest | `services/*.service.ts`、`utils/hash.ts`、`utils/jwt.ts` |
| 集成 | vitest + supertest | 每个 `routes/*.routes.ts`：正常 / 异常 / 鉴权 / 数据隔离路径 |
| 数据库 | 真实 MySQL `qingzhang` | 测试间通过唯一 username 隔离，`afterAll` 用多表 DELETE JOIN 清理 |

**已覆盖**（共 71 用例）：

| 测试文件 | 覆盖端点 | 用例数 |
|---|---|---|
| `tests/auth.routes.test.ts` | `/api/auth/*` | 8 |
| `tests/categories.routes.test.ts` | `GET /api/categories` | 5 |
| `tests/accounts.routes.test.ts` | `/api/accounts` | 7 |
| `tests/records.routes.test.ts` | `/api/records` | 11 |
| `tests/reports.routes.test.ts` | `/api/reports/{monthly,yearly}` | 7 |
| `tests/users.routes.test.ts` | `/api/users/me*` | 13 |

---

## 十二、交付清单（实施完成后）

- [x] `package.json` / `tsconfig.json` / `.env.example` / `.gitignore`
- [x] 上述目录树中所有源文件
- [x] DB 初始化 scripts：`schema.ts` / `seed.ts` / `init.ts`
- [x] `README.md`：启动方式、接口 curl 示例、环境变量说明
- [x] SPEC 已实现检查表
- [x] 业务 API：categories / accounts / records / reports / users
- [x] 注册自动建账本 + 5 默认账户

---

## 十三、与前端的契约

> **状态（2026-08-28）**：Phase B 已落地。前端 mock 全部删除，所有页面走 API。
> 改造 commit 起点：`cb64823 feat(frontend): 新增业务接口模块` 起一系列提交。
> 后续修复合入：`605373d 数据不展示问题`（4 个 list wrapper）/ `547308a fix(auth): /api/auth/me 返回 user 补全 avatar/gender/age` / `290bc5b fix(frontend): 月报/年报响应去掉多余 report 包装`。

前端 `useAuthStore` 改造需做：

1. `register/login` 改为 `fetch('/api/auth/register')` + `fetch('/api/auth/login')`
2. 登录态改为持久化 `{ token, user }`，并加 `Authorization` 头
3. 删除对 Dexie `users` 表的读写
4. 路由守卫逻辑保留不变

业务模块接入要点：

1. 删除 `src/data/transactions.ts` / `categories.ts` / `accounts.ts`
2. 各页面 `useEffect` 改为 `fetch('/api/<module>')`，统一封装 `apiClient`
3. JWT 通过 `Authorization: Bearer <token>` 头传递，401 时前端清空 store 并跳登录
4. 表单的分类 / 账户下拉改为先 `GET /api/categories`、`GET /api/accounts` 拿数据

---

## 十四、开放问题

| # | 问题 | 默认决定 |
|---|------|---------|
| Q1 | 是否同步改造前端？ | ✅ **已落地**（Phase B, 2026-08 期间，参见 §13 顶部状态行） |
| Q2 | token 存哪里？ | 前端 `localStorage`（保留 Zustand persist） |
| Q3 | 接口前缀 | `/api/<module>/*` |
| Q4 | JWT issuer | 不设置（V1.1 再说） |
| Q5 | records 是否支持多账户分摊？ | **否**（V1.1） |
| Q6 | 月度报表是否支持环比？ | ✅ 已包含 `lastMonth` |
