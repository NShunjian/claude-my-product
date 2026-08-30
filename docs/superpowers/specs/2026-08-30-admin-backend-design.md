# Admin Backend Subsystem — Design Spec

- **Date**: 2026-08-30
- **Project**: 轻账 QingZhang (记账 PWA)
- **Scope**: Add admin backend subsystem with RBAC, audit log, and dedicated admin SPA
- **Status**: Approved (pending writing-plans)

---

## 1. Goals & Non-Goals

### Goals
- 后台管理员可查看/管理所有用户、账本、流水、预设分类、审计日志
- 完整 RBAC:`super_admin` / `admin` / `viewer` 三角色 + 资源:动作 权限码
- 管理员操作全程落审计 (`admin_audit_logs`),含 before/after snapshot
- 独立前端 admin SPA,与普通用户视觉/路由彻底隔开
- 现有用户流程零破坏 (additive only)

### Non-Goals (YAGNI)
- 角色/权限的可视化编辑页 (3 个角色硬编码)
- 管理员双因素认证
- WebSocket 实时操作通知
- 软删除恢复 UI (`@TableLogic` 已支持,前端不暴露)
- 撤销角色后立刻生效 (依赖 24h 短 token 自然过期)

---

## 2. Architecture

3 组件,additive 模式:

```
┌─────────────────────┐    ┌─────────────────────┐
│ frontend-react-    │    │ admin-frontend      │  ← NEW: 独立 Vite SPA
│ java (普通用户)      │    │ (管理员)             │
│  /login, /, ...     │    │  /admin/login, ...  │
└─────────┬───────────┘    └─────────┬───────────┘
          │ /api/*                  │ /api/admin/*
          └────────────┬───────────┘
                       ▼
┌───────────────────────────────────────────────┐
│  Spring Boot 后端 — 新增 com.qingzhang.admin 包 │
│  JwtAuthFilter → AdminAuthInterceptor →       │
│  Controller → Service → Mapper                │
└─────────────────────┬─────────────────────────┘
                      ▼
┌───────────────────────────────────────────────┐
│  MySQL — Flyway V5 加 5 张表                  │
│  admin_roles / admin_permissions /            │
│  admin_role_permissions /                     │
│  admin_user_roles / admin_audit_logs          │
└───────────────────────────────────────────────┘
```

---

## 3. Database (Flyway V5)

新文件:`005.后端代码（Java工程师）/src/main/resources/db/migration/V5__admin_rbac_and_audit.sql`

### 3.1 admin_roles
```sql
id BIGINT UNSIGNED PK AUTO_INCREMENT
uuid CHAR(36) UNIQUE
code VARCHAR(32) UNIQUE           -- 'super_admin' / 'admin' / 'viewer'
name VARCHAR(50)
description VARCHAR(255)
status TINYINT DEFAULT 1          -- 1=启用 0=禁用
created_at DATETIME(3)
updated_at DATETIME(3) ON UPDATE CURRENT_TIMESTAMP(3)
deleted_at DATETIME(3) NULL       -- @TableLogic
```

### 3.2 admin_permissions
```sql
id BIGINT UNSIGNED PK AUTO_INCREMENT
code VARCHAR(64) UNIQUE           -- 'user:list', 'category:preset:create', ...
name VARCHAR(100)
resource VARCHAR(32)              -- 'user' / 'role' / 'category' / 'book' / 'record' / 'dashboard' / 'audit'
action VARCHAR(32)                -- 'list' / 'view' / 'create' / 'update' / 'delete' / 'disable' / 'reset_password' / 'grant' / 'revoke'
created_at DATETIME(3)
```

### 3.3 admin_role_permissions
```sql
role_id BIGINT UNSIGNED  → admin_roles.id  ON DELETE CASCADE
permission_id BIGINT UNSIGNED → admin_permissions.id ON DELETE CASCADE
PRIMARY KEY (role_id, permission_id)
```

### 3.4 admin_user_roles
```sql
user_id BIGINT UNSIGNED → users.id ON DELETE CASCADE
role_id BIGINT UNSIGNED → admin_roles.id ON DELETE CASCADE
granted_at DATETIME(3)
granted_by BIGINT UNSIGNED NULL  → users.id (授予人)
PRIMARY KEY (user_id, role_id)
KEY idx_admin_user_roles_user (user_id)
```

### 3.5 admin_audit_logs
```sql
id BIGINT UNSIGNED PK AUTO_INCREMENT
uuid CHAR(36) UNIQUE
actor_user_id BIGINT UNSIGNED NULL  → users.id (NULL 表示系统引导)
actor_username VARCHAR(50)         -- 冗余存,user 被删也能追溯
action VARCHAR(64)                 -- 'user.disable' / 'category.create' / ...
target_type VARCHAR(32) NULL       -- 'user' / 'category' / 'book' ...
target_id BIGINT UNSIGNED NULL
before_snapshot JSON NULL
after_snapshot JSON NULL
ip VARCHAR(64) NULL
user_agent VARCHAR(255) NULL
result ENUM('success','failure') NOT NULL DEFAULT 'success'
error_msg VARCHAR(500) NULL
created_at DATETIME(3)
KEY idx_audit_actor_created (actor_user_id, created_at)
KEY idx_audit_target (target_type, target_id)
KEY idx_audit_action (action, created_at)
```

### 3.6 Seed Data (V5 migration 内嵌)

**3 个角色**:
| code | name | description |
|---|---|---|
| `super_admin` | 超级管理员 | 全部权限 |
| `admin` | 管理员 | 除角色管理外的全部 |
| `viewer` | 只读审计员 | 仅 `*:list` + `*:view` |

**~15 个权限码**:
```
user:list, user:view, user:disable, user:reset_password
role:list, role:grant, role:revoke
category:preset:list, :create, :update, :delete
book:list, book:view
record:list, record:view
dashboard:view
audit:list
```

**角色-权限映射** (默认):
- `super_admin` → 全部
- `admin` → 除 `role:grant`/`role:revoke`/`audit:list` 外的全部 (审计日志仅 super_admin 可看)
- `viewer` → `user:list`/`user:view` + `book:list`/`book:view` + `record:list`/`record:view` + `dashboard:view`

> 注:V5 migration **不创建任何 user_role 映射**(无用户存在时);引导由 §6 CommandLineRunner 完成。

---

## 4. Backend — Java/Spring

### 4.1 Package Layout

新包 `com.qingzhang.admin`:

```
admin/
├── entity/
│   ├── AdminRole.java                @TableName("admin_roles")
│   ├── AdminPermission.java          @TableName("admin_permissions")
│   ├── AdminRolePermission.java      @TableName("admin_role_permissions") @IdType.NONE 复合主键
│   ├── AdminUserRole.java            @TableName("admin_user_roles")      @IdType.NONE 复合主键
│   └── AdminAuditLog.java            @TableName("admin_audit_logs")
├── mapper/
│   ├── AdminRoleMapper.java
│   ├── AdminPermissionMapper.java
│   ├── AdminRolePermissionMapper.java
│   ├── AdminUserRoleMapper.java
│   └── AdminAuditLogMapper.java
├── dto/
│   ├── AdminMeResponse.java          user + isSuperAdmin + permissions + roleCodes
│   ├── AdminUserListItem.java        user 概要
│   ├── AdminUserDetailResponse.java
│   ├── AdminUpdateUserStatusRequest.java
│   ├── AdminResetPasswordRequest.java  (新密码字段,admin 重置专用)
│   ├── AdminResetPasswordResponse.java (返回明文密码 — 一次性展示)
│   ├── AdminGrantRoleRequest.java
│   ├── AdminPresetCategoryRequest.java
│   ├── AdminBookListItem.java
│   ├── AdminRecordListItem.java
│   ├── AdminDashboardStats.java
│   └── AdminAuditLogListItem.java
├── service/
│   ├── AdminAuthService.java         me()、loadPermissionsAtLogin()
│   ├── AdminUserService.java         list/getMe-as-admin/disable/resetPassword/grantRole/revokeRole
│   ├── AdminCategoryService.java     preset CRUD
│   ├── AdminBookService.java         list+detail (read-only)
│   ├── AdminRecordService.java       list (read-only, filter)
│   ├── AdminDashboardService.java    SQL 聚合 stats
│   └── AdminAuditService.java        record() — 所有 service 手动调
├── controller/
│   ├── AdminAuthController.java      GET /api/admin/auth/me
│   ├── AdminUsersController.java     /api/admin/users[/{id}[/status|/reset-password|/roles]]
│   ├── AdminCategoriesController.java /api/admin/categories/preset[...]
│   ├── AdminBooksController.java     /api/admin/books[/{uuid}]
│   ├── AdminRecordsController.java   /api/admin/records
│   ├── AdminDashboardController.java /api/admin/dashboard
│   └── AdminAuditLogsController.java /api/admin/audit-logs
├── security/
│   ├── RequiresPermission.java       @RequiresPermission("user:list") 方法注解
│   ├── AdminAuthInterceptor.java     HandlerInterceptor,扫 @RequiresPermission + 校验
│   └── AdminSecurityContext.java     request-scoped,缓存 userId/permissions/isSuperAdmin
└── audit/
    └── (service 同上,此目录预留 AOP,首版手动调用)
```

### 4.2 Auth 改造 (最小侵入)

**修改文件**:
- `auth/JwtUtil.java`:
  - `issue(long userId, Set<String> permissions, Set<String> roleCodes, boolean isSuperAdmin)` — overload
  - claims 多带: `permissions` (String[]), `roleCodes` (String[]), `isSuperAdmin` (Boolean)
- `auth/JwtAuthFilter.java`:
  - 解析后除 userId 外,再设 `permissions` / `roleCodes` / `isSuperAdmin` 到 request attr
- `auth/AuthService.java`:
  - `register()` / `login()` 末尾调 `permissionsService.resolvePermissions(userId)` 算出 Set
  - 调 `jwtUtil.issue(userId, permissions, roleCodes, isSuperAdmin)`
- `auth/AuthController.java`:
  - `/api/auth/login` `/api/auth/register` 响应多带 `permissions` / `roleCodes` / `isSuperAdmin` (普通用户也带,空集合而已 — 前端可忽略)
  - 新增 `GET /api/admin/auth/me` 单独端点供 admin SPA 用,返回精简字段

**新配置项** (`application.yml`):
```yaml
jwt:
  secret: ...
  expiration-days: 7               # 普通用户
  admin-expiration-hours: 24       # 管理员 (新)
admin:
  bootstrap:
    username: ${ADMIN_BOOTSTRAP_USERNAME:}
    password: ${ADMIN_BOOTSTRAP_PASSWORD:}
```

### 4.3 AdminAuthInterceptor

注册到 `/api/admin/**`,放过 `/api/admin/auth/login` (登录本身查不到 token):

```java
public boolean preHandle(req, res, handler) {
    if (handler instanceof HandlerMethod hm
        && hm.hasMethodAnnotation(RequiresPermission.class)) {
        String code = hm.getMethodAnnotation(RequiresPermission.class).value();
        Boolean isSuper = (Boolean) req.getAttribute("isSuperAdmin");
        Set<String> perms = (Set<String>) req.getAttribute("permissions");
        if (Boolean.TRUE.equals(isSuper)) return true;
        if (perms != null && perms.contains(code)) return true;
        throw new BizException(1403, "无权限: " + code);
    }
    return true;
}
```

**已知限制** (spec 内明文): 撤销角色后,管理员的现有 token 仍带旧 permissions,直到 24h 自然过期。如需立即生效,可调 `POST /api/admin/users/{id}/logout-everywhere` (后续需求,本版不实现)。

### 4.4 API 端点总表

| Method | Path | Controller | @RequiresPermission |
|---|---|---|---|
| GET | `/api/admin/auth/me` | AdminAuthController | (none — 任何登录用户都能查自己的权限) |
| GET | `/api/admin/users` | AdminUsersController | `user:list` |
| GET | `/api/admin/users/{id}` | AdminUsersController | `user:view` |
| PATCH | `/api/admin/users/{id}/status` | AdminUsersController | `user:disable` |
| POST | `/api/admin/users/{id}/reset-password` | AdminUsersController | `user:reset_password` |
| POST | `/api/admin/users/{id}/roles` | AdminUsersController | `role:grant` |
| DELETE | `/api/admin/users/{id}/roles/{roleCode}` | AdminUsersController | `role:revoke` |
| GET | `/api/admin/categories/preset` | AdminCategoriesController | `category:preset:list` |
| POST | `/api/admin/categories/preset` | AdminCategoriesController | `category:preset:create` |
| PATCH | `/api/admin/categories/preset/{uuid}` | AdminCategoriesController | `category:preset:update` |
| DELETE | `/api/admin/categories/preset/{uuid}` | AdminCategoriesController | `category:preset:delete` |
| GET | `/api/admin/books` | AdminBooksController | `book:list` |
| GET | `/api/admin/books/{uuid}` | AdminBooksController | `book:view` |
| GET | `/api/admin/records` | AdminRecordsController | `record:list` |
| GET | `/api/admin/dashboard` | AdminDashboardController | `dashboard:view` |
| GET | `/api/admin/audit-logs` | AdminAuditLogsController | `audit:list` |

**复用端点**:
- `POST /api/auth/login` 与 `POST /api/auth/register` — 不变,前端 admin SPA 直接复用。响应里多带 `permissions`/`roleCodes`/`isSuperAdmin`,普通用户这 3 个字段为空。

### 4.5 错误码 (扩展 ErrorCode)

```java
// admin 模块错误码区间:14xx
int CODE_ADMIN_AUTH_REQUIRED = 1401;
int CODE_ADMIN_PERMISSION_DENIED = 1403;
int CODE_ADMIN_USER_NOT_FOUND = 1410;
int CODE_ADMIN_ROLE_NOT_FOUND = 1420;
int CODE_ADMIN_TARGET_NOT_FOUND = 1490;
```

---

## 5. Audit Log 设计

### 5.1 写库时机 (手动调用,首版不上 AOP)

每个 admin service 关键方法 **首尾** 调 `AdminAuditService.record(...)`:

```java
public void disableUser(long actorId, long targetId, boolean newStatus) {
    User before = userMapper.selectById(targetId);
    try {
        // ... 业务逻辑
        audit.record(actorId, "user.disable", "user", targetId,
                     snapshotOf(before), snapshotOf(after), "success", null, ip, ua);
    } catch (BizException e) {
        audit.record(actorId, "user.disable", "user", targetId,
                     snapshotOf(before), null, "failure", e.getMessage(), ip, ua);
        throw e;
    }
}
```

`AdminAuditService.record(...)` 接收 `(actorId, action, targetType, targetId, before, after, result, errorMsg, ip, userAgent)`。

**IP / UA 来源**: `HttpServletRequest.getRemoteAddr()` + `getHeader("User-Agent")`,由 Controller 注入到 service 或存 `RequestContextHolder`。

### 5.2 审计日志查询端点

`GET /api/admin/audit-logs?actor=&action=&targetType=&targetId=&from=&to=&page=1&size=20`

返回 `AdminAuditLogListItem { id, uuid, actorUsername, action, targetType, targetId, result, createdAt }`(不返完整 snapshot,提供 `GET /api/admin/audit-logs/{uuid}` 看明细)。

---

## 6. Bootstrap — 首次超级管理员

`QingZhangApplication.java` 加 `CommandLineRunner`:

```java
@Bean
CommandLineRunner bootstrapAdmin(AdminBootstrapService svc) {
    return args -> svc.bootstrapIfEmpty();
}
```

`AdminBootstrapService.bootstrapIfEmpty()`:
1. 读 `admin.bootstrap.username` 和 `admin.bootstrap.password` 配置
2. 任一为空 → 跳过,日志 INFO
3. `admin_user_roles` 表为空 且 env 都设了:
   - `findOrCreateUser(username, password)` — 不存在就 register 流程 (送默认账本+账户)
   - 授予 `super_admin`
   - 日志:WARN 级别输出 `Bootstrap super admin created: <username>` (**不打印密码**)
4. 已存在映射 → 跳过

**生产建议**:
```bash
ADMIN_BOOTSTRAP_USERNAME=root \
ADMIN_BOOTSTRAP_PASSWORD=$(openssl rand -hex 12) \
java -jar qingzhang.jar
# 启动后立刻 unset,避免泄露
```

---

## 7. Frontend — admin-frontend (新项目)

### 7.1 项目位置
`003.前端代码（前端工程师）/admin-frontend/`

### 7.2 依赖
```json
{
  "dependencies": {
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "react-router-dom": "^6.26.0"
  },
  "devDependencies": {
    "@types/react": "^18.3.0",
    "@types/react-dom": "^18.3.0",
    "@vitejs/plugin-react": "^4.3.0",
    "typescript": "^5.5.0",
    "vite": "^5.4.0"
  }
}
```

> **不引 UI 库** (Ant Design / MUI):后端 admin 表格不复杂,plain div + table 够用。
> **不引状态库** (Redux/Zustand):每个页面用 useState + useEffect 即可。
> 与主前端 `frontend-react-java` 保持技术栈同源,后续可复用组件直接复制。

### 7.3 文件结构
```
admin-frontend/
├── package.json
├── tsconfig.json
├── vite.config.ts                    # proxy /api → http://localhost:8080
├── index.html
└── src/
    ├── main.tsx
    ├── App.tsx                       # 路由表
    ├── index.css                     # 基础样式 (跟主前端用同一套 Tailwind 变量)
    ├── auth/
    │   ├── AdminAuthContext.tsx      # token + user + permissions 缓存
    │   └── AdminProtectedRoute.tsx   # 无 token → /admin/login;无权限 → /admin/forbidden
    ├── layouts/
    │   └── AdminLayout.tsx           # 顶栏 + 侧栏 + Outlet
    ├── components/
    │   ├── DataTable.tsx             # 通用表格 (columns + data + loading)
    │   ├── ConfirmDialog.tsx         # 危险操作二次确认
    │   ├── Toast.tsx                 # 全局提示
    │   └── PermissionGate.tsx        # <PermissionGate need="user:disable"> 包裹按钮
    ├── api/
    │   ├── client.ts                 # fetch wrapper + ApiError + 401 → 清 token
    │   ├── adminAuth.ts
    │   ├── adminUsers.ts
    │   ├── adminCategories.ts
    │   ├── adminBooks.ts
    │   ├── adminRecords.ts
    │   ├── adminDashboard.ts
    │   └── adminAuditLogs.ts
    └── pages/
        ├── AdminLogin.tsx
        ├── AdminForbidden.tsx
        ├── AdminDashboard.tsx        # 4 个数字卡片 + 最近 7 天新增用户折线图
        ├── AdminUsers.tsx            # 表格 + 详情 Modal + 操作 (禁用/启用/重置密码/授角色)
        ├── AdminCategories.tsx       # 预设分类 CRUD
        ├── AdminBooks.tsx            # 跨用户账本浏览
        ├── AdminRecords.tsx          # 跨用户流水筛选
        └── AdminAuditLogs.tsx        # 审计列表 + 明细抽屉
```

### 7.4 路由表
```tsx
<Routes>
  <Route path="/admin/login" element={<AdminLogin />} />
  <Route element={<AdminProtectedRoute />}>
    <Route element={<AdminLayout />}>
      <Route path="/admin"            element={<AdminDashboard />} />
      <Route path="/admin/users"      element={<AdminUsers />} />
      <Route path="/admin/categories" element={<AdminCategories />} />
      <Route path="/admin/books"      element={<AdminBooks />} />
      <Route path="/admin/records"    element={<AdminRecords />} />
      <Route path="/admin/audit-logs" element={<AdminAuditLogs />} />
    </Route>
  </Route>
  <Route path="/admin/forbidden" element={<AdminForbidden />} />
  <Route path="*"               element={<Navigate to="/admin" replace />} />
</Routes>
```

### 7.5 AdminLayout
```
┌──────────────────────────────────────────────────┐
│ 轻账管理后台    [用户名 ▼] [角色: super_admin] [退出]│ ← TopBar
├──────────┬───────────────────────────────────────┤
│ Dashboard│                                       │
│ Users    │                                       │
│ Categories   <Outlet />                          │
│ Books    │                                       │
│ Records  │                                       │
│ Audit    │                                       │
└──────────┴───────────────────────────────────────┘
```

### 7.6 Auth Flow
- `AdminLogin` 调 `POST /api/auth/login` (复用主端点),响应里读 `isSuperAdmin`/`permissions`/`roleCodes`
- 若 `permissions` 为空 → `navigate('/admin/forbidden')`
- `localStorage` key 用 `qz_admin_token` (与主前端 `qz_token` 隔离)
- `AdminAuthContext` 在 mount 时若有 token → 调 `GET /api/admin/auth/me` 校验
- `client.ts` 监听 401 → 清 token + 跳 `/admin/login`

### 7.7 开发与部署

**Dev**:
- 后端 `mvn spring-boot:run` 跑 8080
- 主前端 `npm run dev` 跑 5173
- admin 前端 `npm run dev -- --port 5174` 跑 5174,Vite proxy `/api` → `localhost:8080`

**Prod (Nginx)**:
```nginx
server {
  listen 80;
  server_name _;
  # admin SPA
  location /admin/ { root /var/www/qingzhang/admin-frontend/dist; try_files $uri /admin/index.html; }
  # 主前端 SPA
  location / { root /var/www/qingzhang/frontend-react-java/dist; try_files $uri /index.html; }
  # API 反代
  location /api/ { proxy_pass http://localhost:8080; }
}
```

---

## 8. 关键文件清单

### 后端 — 新增 (25 个文件)
1. `db/migration/V5__admin_rbac_and_audit.sql`
2. `admin/entity/AdminRole.java`
3. `admin/entity/AdminPermission.java`
4. `admin/entity/AdminRolePermission.java`
5. `admin/entity/AdminUserRole.java`
6. `admin/entity/AdminAuditLog.java`
7. `admin/mapper/AdminRoleMapper.java`
8. `admin/mapper/AdminPermissionMapper.java`
9. `admin/mapper/AdminRolePermissionMapper.java`
10. `admin/mapper/AdminUserRoleMapper.java`
11. `admin/mapper/AdminAuditLogMapper.java`
12. `admin/dto/AdminMeResponse.java`
13. `admin/dto/AdminUserListItem.java`
14. `admin/dto/AdminUserDetailResponse.java`
15. `admin/dto/AdminUpdateUserStatusRequest.java`
16. `admin/dto/AdminResetPasswordRequest.java`
17. `admin/dto/AdminResetPasswordResponse.java`
18. `admin/dto/AdminGrantRoleRequest.java`
19. `admin/dto/AdminPresetCategoryRequest.java`
20. `admin/dto/AdminBookListItem.java`
21. `admin/dto/AdminRecordListItem.java`
22. `admin/dto/AdminDashboardStats.java`
23. `admin/dto/AdminAuditLogListItem.java`
24. `admin/security/RequiresPermission.java`
25. `admin/security/AdminAuthInterceptor.java`
26. `admin/security/AdminSecurityContext.java`
27. `admin/service/AdminBootstrapService.java`
28. `admin/service/AdminAuthService.java`
29. `admin/service/AdminUserService.java`
30. `admin/service/AdminCategoryService.java`
31. `admin/service/AdminBookService.java`
32. `admin/service/AdminRecordService.java`
33. `admin/service/AdminDashboardService.java`
34. `admin/service/AdminAuditService.java`
35. `admin/controller/AdminAuthController.java`
36. `admin/controller/AdminUsersController.java`
37. `admin/controller/AdminCategoriesController.java`
38. `admin/controller/AdminBooksController.java`
39. `admin/controller/AdminRecordsController.java`
40. `admin/controller/AdminDashboardController.java`
41. `admin/controller/AdminAuditLogsController.java`

### 后端 — 修改 (8 个文件)
1. `auth/JwtUtil.java` — overload `issue(...)` 加 permissions/roleCodes/isSuperAdmin claims
2. `auth/JwtAuthFilter.java` — 多 set 3 个 request attr
3. `auth/AuthService.java` — login/register 末尾 resolvePermissions + 新 issue overload
4. `auth/AuthController.java` — 响应多带 3 字段
5. `auth/AuthFilterConfig.java` — 不需改 (filter 自动覆盖 /api/admin/*)
6. `config/MybatisPlusConfig.java` — 可能需注册 admin 包扫描 (若没设全局扫描)
7. `common/ErrorCode.java` — 加 14xx 区间常量
8. `QingZhangApplication.java` — 加 CommandLineRunner bean

### 前端 — 新增 (~30 个文件)
全部位于 `003.前端代码（前端工程师）/admin-frontend/` 新项目。

---

## 9. 测试与验证

每个 service 加一个最小 `demo()` main 或一个 `@SpringBootTest` 切片:

| 单元 | 验证 |
|---|---|
| `AdminAuthInterceptor` | 4 个分支:无 token→401, 有效 token 无权限→1403, super_admin 通过, 普通权限通过 |
| `AdminBootstrapService` | 空表 + env 设 → 创建用户+super_admin;再次启动 → 跳过 |
| `AdminAuditService.record()` | success/failure 两种 result 都写库 |
| `AdminUserService.disableUser()` | 状态更新 + 审计落库 + 旧 token 仍能调用普通端点 |
| `AdminCategoryService` | CRUD + 软删 + 审计 4 行 |

端到端冒烟 (手动):
```bash
# 1. 启后端,设 env
ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD=Root@12345 mvn spring-boot:run

# 2. 登录拿 token
curl -X POST localhost:8080/api/auth/login -d '{"username":"root","password":"Root@12345"}'

# 3. 调 admin 端点
curl -H "Authorization: Bearer <token>" localhost:8080/api/admin/users
curl -H "Authorization: Bearer <token>" localhost:8080/api/admin/dashboard

# 4. 启动 admin SPA
cd admin-frontend && npm run dev
# 浏览器开 http://localhost:5174 → 用 root 登录 → 看见 dashboard
```

---

## 10. Out of Scope (后续可加)

- 撤销角色立即生效 (`force-logout` 端点 + token 黑名单)
- 角色/权限可视化编辑 (V2)
- 管理员 2FA
- 审计日志可视化筛选 (时间段/操作类型分布)
- 导出审计到 S3/OSS
- 管理员操作实时推送 WebSocket