# Admin 后台管理子系统

## 概述

为 QingZhang 后端新增的后台管理子系统,与普通用户 API 完全隔离,通过 `/api/admin/**` 前缀统一挂载。需要管理员角色才能访问,基于 RBAC 权限模型(角色 → 权限码)做精细控制。

## 架构概览

```
┌─────────────────────────────────────────────────────────┐
│ 前端 admin SPA (B 计划,独立 Vite 工程)                    │
└─────────────────┬───────────────────────────────────────┘
                  │ HTTP + Bearer JWT
                  ▼
┌─────────────────────────────────────────────────────────┐
│ Spring Boot 后端                                         │
│  JwtAuthFilter ─── 解 token, 设置 userId request attr    │
│         │                                                │
│         ▼                                                │
│  AdminAuthInterceptor ─ 401/403 拦截                       │
│   ├─ JWT 有效? 否则 401                                   │
│   ├─ JWT iat 在 24h 内? 否则 401 (admin token 独立短时)   │
│   ├─ 用户至少有 admin 角色? 否则 401                        │
│   └─ @RequiresPermission 通过? 否则 403                    │
│         │                                                │
│         ▼                                                │
│  Controller / Service                                    │
│   ├─ AdminUserService          → user:list / detail / ...│
│   ├─ AdminCategoryService      → category:preset:*        │
│   ├─ AdminBookService          → book:list                │
│   ├─ AdminRecordService        → record:list              │
│   ├─ DashboardService          → dashboard:view           │
│   ├─ AdminAuditLogsService     → audit:list (super_admin)│
│   └─ AdminAuthController.me()  → 无 perm 限制             │
│         │                                                │
│         ▼                                                │
│  AdminAuditService.record*()  → 写 admin_audit_logs       │
└─────────────────────────────────────────────────────────┘
                  │
                  ▼
   Flyway V5__admin_rbac_and_audit.sql (5 表 + 3 角色 + 17 权限)
```

## 数据模型

5 张 admin_* 表(V5 Flyway 迁移):

| 表名                  | 说明                          |
|----------------------|------------------------------|
| `admin_roles`         | 角色: super_admin / admin / viewer |
| `admin_permissions`   | 权限码 (resource:action 形式)        |
| `admin_role_permissions` | 角色-权限多对多                |
| `admin_user_roles`    | 用户-角色多对多                  |
| `admin_audit_logs`    | 审计日志                        |

3 个角色 + 17 个权限码已 seed。详细见 `db/migration/V5__admin_rbac_and_audit.sql`。

## 权限矩阵

| 权限码                  | 资源       | 操作         | super_admin | admin | viewer |
|------------------------|-----------|--------------|:-----------:|:-----:|:------:|
| `user:list`            | user      | list          | ✓ | ✓ | ✓ |
| `user:detail`          | user      | detail        | ✓ | ✓ | ✓ |
| `user:disable`         | user      | status toggle | ✓ | ✓ | - |
| `user:reset_password`  | user      | reset pwd     | ✓ | ✓ | - |
| `user:grant_role`      | user      | role mgr     | ✓ | - | - |
| `category:preset:list`   | category  | list         | ✓ | ✓ | ✓ |
| `category:preset:create` | category  | create       | ✓ | ✓ | - |
| `category:preset:update` | category  | update       | ✓ | ✓ | - |
| `category:preset:delete` | category  | delete       | ✓ | - | - |
| `book:list`            | book      | list          | ✓ | ✓ | ✓ |
| `book:view`            | book      | detail        | ✓ | ✓ | ✓ |
| `record:list`          | record    | list          | ✓ | ✓ | ✓ |
| `record:view`          | record    | detail        | ✓ | ✓ | ✓ |
| `dashboard:view`       | dashboard | view          | ✓ | ✓ | ✓ |
| `audit:list`           | audit     | list          | ✓ | - | - |
| `role:grant`           | role      | grant         | ✓ | - | - |
| `role:revoke`          | role      | revoke        | ✓ | - | - |

## 端点目录

所有 admin 端点位于 `/api/admin/**`。完整列表见下表。

### 自身信息

| Method | Path                          | 权限              | 说明 |
|--------|-------------------------------|-----------------|------|
| GET    | `/api/admin/auth/me`          | (无)             | 当前 admin 自己的 profile + permissions + roleCodes |

### 用户管理

| Method | Path                                  | 权限                |
|--------|---------------------------------------|--------------------|
| GET    | `/api/admin/users`                    | `user:list`         |
| GET    | `/api/admin/users/{id}`               | `user:detail`       |
| PATCH  | `/api/admin/users/{id}/status`        | `user:disable`      |
| POST   | `/api/admin/users/{id}/reset-password`| `user:reset_password`|
| POST   | `/api/admin/users/{id}/roles`          | `user:grant_role`   |
| DELETE | `/api/admin/users/{id}/roles/{code}`  | `user:grant_role`   |

### 预设分类

| Method | Path                                  | 权限                  |
|--------|---------------------------------------|----------------------|
| GET    | `/api/admin/categories`               | `category:preset:list` |
| POST   | `/api/admin/categories`               | `category:preset:create`|
| PATCH  | `/api/admin/categories/{id}`          | `category:preset:update`|
| PATCH  | `/api/admin/categories/{id}/status`   | `category:preset:update`|
| DELETE | `/api/admin/categories/{id}`          | `category:preset:delete`|

### 审计视图

| Method | Path                                  | 权限           |
|--------|---------------------------------------|---------------|
| GET    | `/api/admin/books`                    | `book:list`    |
| GET    | `/api/admin/records`                  | `record:list`  |
| GET    | `/api/admin/dashboard`                | `dashboard:view` |

### 审计日志

| Method | Path                                  | 权限           |
|--------|---------------------------------------|---------------|
| GET    | `/api/admin/audit-logs`               | `audit:list`   |
| GET    | `/api/admin/audit-logs/{uuid}`        | `audit:list`   |

## 引导(Bootstrap)

通过环境变量激活(幂等,安全重复运行):

```bash
export ADMIN_BOOTSTRAP_USERNAME=superadmin
export ADMIN_BOOTSTRAP_PASSWORD='StrongP@ssw0rd!'
./start-backend   # 或 mvn spring-boot:run
```

应用启动时,`AdminBootstrapService` 会:
1. 检查两个环境变量是否都设置(任一为空 → 跳过)
2. 查找 `super_admin` role(V5 seed,失败 → WARN + 跳过)
3. 创建用户(已存在 → 跳过;BCrypt 编码密码)
4. 授权 `super_admin` 角色(已授权 → 跳过)

**生产环境**:仅在首次部署设置一次,之后清空环境变量。

## 审计日志格式

`admin_audit_logs` 表每条记录包含:

| 字段              | 类型      | 说明                                         |
|------------------|----------|---------------------------------------------|
| `uuid`            | string   | 公开标识(用于 detail API)                     |
| `actor_user_id`   | long     | 操作人 user id                              |
| `actor_username`  | string   | 操作人 username                              |
| `action`          | string   | 操作码:`user.enable` / `category.preset.create` 等 |
| `target_type`     | string   | 资源类型:`user` / `category` 等                |
| `target_id`       | long     | 资源 id                                      |
| `before_snapshot` | string   | 操作前快照 (JSON)                              |
| `after_snapshot`  | string   | 操作后快照 (JSON)                              |
| `ip`              | string   | 客户端 IP                                    |
| `user_agent`      | string   | 客户端 UA                                    |
| `result`          | string   | `success` / `failure`                        |
| `error_msg`       | string   | 失败原因(failure 时填)                          |
| `created_at`      | instant  | 操作时间                                      |

## 冒烟测试

仓库根目录提供 `admin-smoke.sh` 端到端冒烟脚本,需要 `curl` + `jq`:

```bash
# 默认账号 admin/admin123
./admin-smoke.sh

# 自定义账号
ADMIN_BOOTSTRAP_USERNAME=foo ADMIN_BOOTSTRAP_PASSWORD=bar ./admin-smoke.sh

# 自定义后端地址
BASE_URL=http://192.168.1.100:4001 ./admin-smoke.sh

# 启用 403 测试 (需要一个非 super_admin 的测试账号)
ADMIN_TEST_USER=tester ADMIN_TEST_PASS=tester123 ./admin-smoke.sh
```

冒烟覆盖:登录 → /me → 6 个列表接口 → 401 → 403(可选)。

## v2 路线图

- `GET /api/admin/users/{id}/records` 单独 user 的流水视图
- `GET /api/admin/users/{id}/books` 单独 user 的账本视图
- 操作撤销 (audit log 反向操作)
- 角色管理 UI (目前只能 DB 操作)
- 实时事件推送 (WebSocket / SSE)
