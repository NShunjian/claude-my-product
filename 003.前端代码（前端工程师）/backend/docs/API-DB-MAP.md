# 轻账 API ↔ 数据库表 映射手册

> **目的**：维护一份"每个 API endpoint 对应底层哪些表/视图、读写关系、关键 SQL 细节"的总册,后续 API 改动或表结构变更都同步更新到这里。
>
> **数据库**:`qingzhang`(MySQL 9.x)  
> **业务主键**:对外用 UUID(`CHAR(36)`,字段名 `uuid`),表内是 `id BIGINT UNSIGNED` 自增物理主键;service 层做 UUID ↔ bigint 互转。  
> **软删**:除 `users` / `categories` / `book_members` 外,所有业务表都有 `deleted_at DATETIME(3)`,查询/列表都过滤 `deleted_at IS NULL`。  
> **视图**:`v_account_balance`(账户实时余额 = `initial_balance + SUM(records.amount WHERE NOT deleted)`),只读。

---

## 1. 完整 endpoint → 表 映射表

### 1.1 Auth 模块 — `backend/src/routes/auth.routes.ts`

| Method | Path | Controller → Service | 涉及表 / 视图 | 写入动作 | 备注 |
|--------|------|---------------------|---------------|---------|------|
| POST | `/api/auth/register` | `auth.controller.register` → `auth.service.register` | **`users`** + **`books`** + **`accounts`** | INSERT users / INSERT books / INSERT accounts ×5 | 一个事务里:建用户 → 建默认账本(个人账本,`is_default=1`)→ 建 5 个默认账户(微信支付 / 支付宝 / 现金 / 银行卡 / 信用卡) |
| POST | `/api/auth/login` | `auth.controller.login` → `auth.service.login` | **`users`** | SELECT users + UPDATE `last_login_at` | 验密码 → 发 JWT |
| GET | `/api/auth/me` | `auth.controller.getCurrentUser` → `auth.service.getCurrentUser` | **`users`** | — | 按 `req.user.sub`(uuid)查;不带任何 JOIN |
| POST | `/api/auth/logout` | `auth.controller.logout` | 无 DB 读写 | — | 前端清 `localStorage.qz_token`;后端目前不维护 token 黑名单 |

### 1.2 Categories 模块 — `routes/categories.routes.ts`

| Method | Path | Controller → Service | 涉及表 / 视图 | 写入动作 | 备注 |
|--------|------|---------------------|---------------|---------|------|
| GET | `/api/categories` | `categories.controller.list` → `categories.service.listByType` | **`categories`** | — | **无需 auth**;返回 `is_preset=1`(系统预设)+ `user_id=当前用户`(用户自定义),按 `sort_order ASC` |

### 1.3 Accounts 模块 — `routes/accounts.routes.ts`(全部 `requireAuth`)

| Method | Path | Controller → Service | 涉及表 / 视图 | 写入动作 | 备注 |
|--------|------|---------------------|---------------|---------|------|
| GET | `/api/accounts` | `accounts.controller.list` → `accounts.service.list` | **`accounts`** + 视图 **`v_account_balance`** | — | JOIN 视图拿 `balance`(初始 + 未删流水);按 `sort_order ASC` |
| POST | `/api/accounts` | `accounts.controller.create` → `accounts.service.create` | **`accounts`** | INSERT + UPDATE 同表 | 设 `is_default=1` 时先批量 `UPDATE ... SET is_default=0 WHERE user_id=?` |
| PATCH | `/api/accounts/:id` | `accounts.controller.update` → `accounts.service.update` | **`accounts`** | UPDATE | 同上,改 is_default 需重置其他 |
| DELETE | `/api/accounts/:id` | `accounts.controller.remove` → `accounts.service.softDelete` | **`accounts`** + **`records`** | UPDATE `accounts.deleted_at` + SELECT `records` 计数 | 有未删流水则拒绝(防余额失真,返回 409) |

### 1.4 Records 模块 — `routes/records.routes.ts`(全部 `requireAuth`)

| Method | Path | Controller → Service | 涉及表 / 视图 | 写入动作 | 备注 |
|--------|------|---------------------|---------------|---------|------|
| GET | `/api/records` | `records.controller.list` → `records.service.list` | **`records`** | — | 过滤 `user_id` + `deleted_at IS NULL`;按 `record_date DESC, id DESC` |
| POST | `/api/records` | `records.controller.create` → `records.service.create` | **`records`** + 校验 SELECT **`categories`** / **`accounts`** | INSERT records | `category_id` / `account_id` 由 uuid → bigint;transfer 时 `to_account_id` 也要解析 |
| PATCH | `/api/records/:id` | `records.controller.update` → `records.service.update` | **`records`** + 校验 SELECT **`categories`** / **`accounts`** | UPDATE | 同上 FK 转换 |
| DELETE | `/api/records/:id` | `records.controller.remove` → `records.service.softDelete` | **`records`** | UPDATE `deleted_at` | 软删;**不改** `accounts.current_balance`,靠视图重算 |

### 1.5 Reports 模块 — `routes/reports.routes.ts`(全部 `requireAuth`)

| Method | Path | Controller → Service | 涉及表 / 视图 | 写入动作 | 备注 |
|--------|------|---------------------|---------------|---------|------|
| GET | `/api/reports/monthly` | `reports.controller.monthly` → `reports.service.monthly` | **`records`** + **`categories`** | — | `GROUP BY category_id` 出分类排行;按 `DAY(record_date)` 出 28-31 桶的 `dailyData` |
| GET | `/api/reports/yearly` | `reports.controller.yearly` → `reports.service.yearly` | **`records`** + **`categories`** | — | 12 个月桶(`MONTH(record_date)`)+ 整年分类排行 |

### 1.6 Users 模块 — `routes/users.routes.ts`(全部 `requireAuth`)

| Method | Path | Controller → Service | 涉及表 / 视图 | 写入动作 | 备注 |
|--------|------|---------------------|---------------|---------|------|
| PATCH | `/api/users/me` | `users.controller.updateProfile` → `users.service.updateProfile` | **`users`** | UPDATE | 字段:`display_name` / `avatar` / `gender` / `age`;部分更新;avatar 支持 URL 或 base64 dataURL(≤30KB,V1.1) |
| POST | `/api/users/me/password` | `users.controller.changePassword` → `users.service.changePassword` | **`users`** | UPDATE `password_hash` | 先 SELECT 验旧密码;成功后再写新 hash(同事务) |

---

## 2. 实体关系图

```
users ─┬─< books ─< book_members >─ users       (V2.0 多账本 / 共享)
       └─< accounts ─┐
                     │
                     ▼
                  records >── categories
                     │
                     └─(transfer: to_account_id → accounts)

v_account_balance  ← 视图,JOIN accounts + records 计算
```

- **`records.account_id`** / **`records.category_id`** 都是 `BIGINT UNSIGNED` 物理外键,但 API 对外只暴露业务 UUID。Service 层负责 UUID ↔ bigint 互转。
- **`v_account_balance`** 是 schema.sql 里的视图,**不写只读**,实时计算;DELETE 流水后账户余额自动跟随更新。

---

## 3. 表的"读 vs 写"角色一览

| 表 | 主要写入者 | 主要读取者 |
|----|----------|-----------|
| `users` | `auth.service.register` / `users.service.updateProfile` / `users.service.changePassword` / `auth.service.login`(last_login_at) | `auth.service.getCurrentUser` / JWT 中间件解析 / `auth.service.login` 验密 |
| `books` | `auth.service.register`(自动建账本) | 未来 `book_members` 关联 / V2.0 多账本功能 |
| `accounts` | `auth.service.register`(5 预设) / `accounts.service.create` / `accounts.service.update` / `accounts.service.softDelete` | `accounts.service.list` / `records.service` 校验 accountId 归属 / `v_account_balance` |
| `categories` | `seed.sql` 灌预设(脚本初始化) | `categories.service.listByType` / `reports.service` 聚合取 name/icon/color |
| `records` | `records.service.create` / `records.service.update` / `records.service.softDelete` | `records.service.list` / `reports.service` 聚合 / `v_account_balance` 计算 |
| `book_members` | V2.0 共享账本再用 | V2.0 |
| `v_account_balance` | (只读视图) | `accounts.service.list` |

---

## 4. 关键 SQL 细节备忘

### 4.1 账户余额视图 `v_account_balance`
```sql
-- 见 004.数据库脚本（数据库管理员DBA）/01_schema_qingzhang.sql 视图段
-- 公式:balance = accounts.initial_balance + SUM(records.amount WHERE NOT deleted)
-- transfer 不重复计入:支出账户 -amount、收入账户 +amount,业务层即可保证
```

### 4.2 service 层 UUID ↔ bigint 转换
- **写**:controller 拿 uuid → service 用 `SELECT id FROM accounts WHERE uuid=? AND user_id=?` 转 bigint → 再 INSERT/UPDATE
- **读**:service `SELECT` 时除 `accounts.uuid` 外,不出 `id`;mapper `toAccount()` 只暴露 uuid 字段

### 4.3 软删一致性
- `accounts.softDelete` 前必查 `SELECT COUNT(*) FROM records WHERE account_id=? AND deleted_at IS NULL`
- `records.softDelete` 不动 `accounts.current_balance`(本项目字段保留但视图重算);**未来若加索引缓存余额需要同步更新**

### 4.4 avatar 列特殊处理(V1.1 起)
- 字段类型从 `VARCHAR(255)` 改为 `MEDIUMTEXT`(容纳 base64)
- 限制:base64 dataURL ≤30KB(30×1024 字节,解码后);URL 形式 max 255 字符
- 仅允许 `data:image/(png|jpeg|webp);base64,` 前缀;SVG dataURL 走显式拒绝(防 XSS)

### 4.5 注册时的"5 默认账户"
- 硬编码 UUID,便于前端类型映射:`account-wechat` / `account-alipay` / `account-cash` / `account-bank` / `account-credit`
- 与 `seed.sql` 里 demo 用户的预设同名,前端无需区分新旧用户

---

## 5. 更新记录

> **格式**:`<日期> — <改动> — <触发原因>`。每次改 API / 改 schema 后追加一行,便于追溯。

| 日期 | 改动 | 触发原因 |
|------|------|---------|
| 2026-08-28 | 初版映射手册(覆盖 Phase A 全部 endpoint) | 用户要求单独整理成可维护文档 |
| 2026-08-28 | `users.avatar` 改为 `MEDIUMTEXT`;新增 base64 ≤30KB 限制 | V1.1 头像上传功能落地 |
| | | |
| | | |

---

## 6. 待补充 / 待确认

- [ ] `GET /api/accounts` 完整 SQL(service 用视图的具体 JOIN 字段)
- [ ] `POST /api/records` UUID 校验失败的错误码(404 vs 400)
- [ ] `v_account_balance` 视图定义原文摘抄(schema.sql 第几行)
- [ ] `reports.monthly` 中 `dailyData` 数组的天数(28/29/30/31)如何根据当月动态决定
- [ ] V1.1 计划新增:手机号注册 / 找回密码 / refresh token 涉及的表
- [ ] V2.0 计划新增:共享账本 / 多币种 / 预算模块涉及的表

---

## 7. 相关文件索引

| 路径 | 作用 |
|------|------|
| `backend/src/routes/*.routes.ts` | API 路由注册 |
| `backend/src/controllers/*.controller.ts` | HTTP 层(参数解析 + 调 service + 返回) |
| `backend/src/services/*.service.ts` | 业务逻辑 + SQL 执行 |
| `backend/src/schemas/*.schema.ts` | zod 校验 / DTO |
| `backend/src/db/pool.ts` | mysql2 连接池 |
| `004.数据库脚本（数据库管理员DBA）/01_schema_qingzhang.sql` | 数据库 schema 源文件 |
| `backend/src/db/sql/01_schema_qingzhang.sql` | 同 schema 的 backend 副本(供脚本读取) |
| `backend/docs/SPEC.md` | API 详细规范(请求/响应字段、错误码) |
