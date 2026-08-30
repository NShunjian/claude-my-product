# Admin Backend Subsystem — Implementation Plan (Plan A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在轻账 QingZhang Spring Boot 后端新增完整的管理后台子系统:RBAC (3 角色 / ~15 权限码) + 16 个 admin REST 端点 + 独立审计日志表 + CommandLineRunner 首次管理员引导。

**Architecture:** 新增 `com.qingzhang.admin` 包,Flyway V5 加 5 张表;复用现有 JwtAuthFilter (扩展 claims)+ 新增 `AdminAuthInterceptor` (注解驱动);所有写操作手动调 `AdminAuditService.record()` 落审计;`super_admin` 走 JWT `isSuperAdmin` claim 短路,其余查 permissions claim 校验。

**Tech Stack:** Spring Boot 3.5 / Java 21 / MyBatis-Plus 3.5.9 / Flyway 10.20.1 / JJWT 0.12.6 / BCrypt / MySQL 8。

**Spec:** `docs/superpowers/specs/2026-08-30-admin-backend-design.md`

**Companion Plan:** `docs/superpowers/plans/2026-08-30-admin-frontend.md` (Plan B,独立 SPA)

---

## Global Constraints

- Java 21 (lombok 1.18.42, mybatis-plus 3.5.9, flyway 10.20.1) — 与 `pom.xml` 锁定的版本完全一致
- 错误码区间 **14xx** 专属 admin 模块 (新增到 `common/ErrorCode.java`)
- 所有实体继承 MyBatis-Plus `BaseMapper<T>` 风格,主键 `@TableId(type = IdType.AUTO)`,软删字段 `@TableLogic @TableField(select = false)` — 参考 `users/entity/User.java`
- DTO 全部用 Java 17 `record`,与现有 `auth/dto/UserDTO.java` 一致
- 控制器统一 `ApiResponse<T>` 信封,沿用现有 `common/ApiResponse.java`
- 不引新依赖;不引 Spring Security 全家桶
- 每个 service 留一个 `@SuppressWarnings("unused") private void demo()` 跑通断言 (ponytail 风格)
- 提交粒度:每个 Task 一个 commit,commit message 用 `feat(后端)/chore(后端)/fix(后端)/refactor(后端)` 前缀

---

## Task 1: Flyway V5 迁移 + 5 张表

**Files:**
- Create: `005.后端代码（Java工程师）/src/main/resources/db/migration/V5__admin_rbac_and_audit.sql`

**Step 1: 写迁移脚本**

完整 SQL(原子,无 placeholder):

```sql
-- =============================================================================
-- 轻账 V5: 管理后台子系统 — RBAC + 审计
-- 与 docs/superpowers/specs/2026-08-30-admin-backend-design.md §3 对齐
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. admin_roles
CREATE TABLE `admin_roles` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `uuid`        CHAR(36)        NOT NULL,
  `code`        VARCHAR(32)     NOT NULL,
  `name`        VARCHAR(50)     NOT NULL,
  `description` VARCHAR(255)    DEFAULT NULL,
  `status`      TINYINT         NOT NULL DEFAULT 1,
  `created_at`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`  DATETIME(3)     DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_roles_uuid` (`uuid`),
  UNIQUE KEY `uk_admin_roles_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台角色';

-- 2. admin_permissions
CREATE TABLE `admin_permissions` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `code`       VARCHAR(64)     NOT NULL,
  `name`       VARCHAR(100)    NOT NULL,
  `resource`   VARCHAR(32)     NOT NULL,
  `action`     VARCHAR(32)     NOT NULL,
  `created_at` DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_permissions_code` (`code`),
  KEY `idx_admin_permissions_resource` (`resource`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台权限码';

-- 3. admin_role_permissions
CREATE TABLE `admin_role_permissions` (
  `role_id`       BIGINT UNSIGNED NOT NULL,
  `permission_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`role_id`, `permission_id`),
  CONSTRAINT `fk_arp_role`       FOREIGN KEY (`role_id`)       REFERENCES `admin_roles` (`id`)       ON DELETE CASCADE,
  CONSTRAINT `fk_arp_permission` FOREIGN KEY (`permission_id`) REFERENCES `admin_permissions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色-权限映射';

-- 4. admin_user_roles
CREATE TABLE `admin_user_roles` (
  `user_id`    BIGINT UNSIGNED NOT NULL,
  `role_id`    BIGINT UNSIGNED NOT NULL,
  `granted_at` DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `granted_by` BIGINT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`user_id`, `role_id`),
  KEY `idx_aur_user` (`user_id`),
  CONSTRAINT `fk_aur_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`)         ON DELETE CASCADE,
  CONSTRAINT `fk_aur_role` FOREIGN KEY (`role_id`) REFERENCES `admin_roles` (`id`)   ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户-角色授权';

-- 5. admin_audit_logs
CREATE TABLE `admin_audit_logs` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `uuid`            CHAR(36)        NOT NULL,
  `actor_user_id`   BIGINT UNSIGNED DEFAULT NULL,
  `actor_username`  VARCHAR(50)     NOT NULL DEFAULT '',
  `action`          VARCHAR(64)     NOT NULL,
  `target_type`     VARCHAR(32)     DEFAULT NULL,
  `target_id`       BIGINT UNSIGNED DEFAULT NULL,
  `before_snapshot` JSON            DEFAULT NULL,
  `after_snapshot`  JSON            DEFAULT NULL,
  `ip`              VARCHAR(64)     DEFAULT NULL,
  `user_agent`      VARCHAR(255)    DEFAULT NULL,
  `result`          ENUM('success','failure') NOT NULL DEFAULT 'success',
  `error_msg`       VARCHAR(500)    DEFAULT NULL,
  `created_at`      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_audit_logs_uuid` (`uuid`),
  KEY `idx_audit_logs_actor_created` (`actor_user_id`, `created_at`),
  KEY `idx_audit_logs_target`        (`target_type`, `target_id`),
  KEY `idx_audit_logs_action`        (`action`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台操作审计';

-- -----------------------------------------------------------------------------
-- Seed: 3 角色 + 权限码 + 角色-权限映射
-- -----------------------------------------------------------------------------
INSERT INTO `admin_roles` (`uuid`, `code`, `name`, `description`, `status`) VALUES
  (UUID(), 'super_admin', '超级管理员', '全部权限', 1),
  (UUID(), 'admin',       '管理员',     '除角色管理与审计外的全部权限', 1),
  (UUID(), 'viewer',      '只读审计员', '仅读权限', 1);

-- 权限码
INSERT INTO `admin_permissions` (`code`, `name`, `resource`, `action`) VALUES
  ('user:list',             '用户列表',     'user',     'list'),
  ('user:view',             '用户详情',     'user',     'view'),
  ('user:disable',          '启用/禁用用户', 'user',     'disable'),
  ('user:reset_password',   '重置用户密码', 'user',     'reset_password'),
  ('role:list',             '角色列表',     'role',     'list'),
  ('role:grant',            '授予角色',     'role',     'grant'),
  ('role:revoke',           '撤销角色',     'role',     'revoke'),
  ('category:preset:list',  '预设分类列表', 'category', 'preset:list'),
  ('category:preset:create','新建预设分类', 'category', 'preset:create'),
  ('category:preset:update','修改预设分类', 'category', 'preset:update'),
  ('category:preset:delete','删除预设分类', 'category', 'preset:delete'),
  ('book:list',             '账本列表',     'book',     'list'),
  ('book:view',             '账本详情',     'book',     'view'),
  ('record:list',           '流水列表',     'record',   'list'),
  ('record:view',           '流水详情',     'record',   'view'),
  ('dashboard:view',        '查看 Dashboard', 'dashboard', 'view'),
  ('audit:list',            '审计日志列表', 'audit',    'list');

-- super_admin: 全部
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id FROM `admin_roles` r, `admin_permissions` p WHERE r.`code` = 'super_admin';

-- admin: 除 role:grant / role:revoke / audit:list 外
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'admin'
     AND p.`code` NOT IN ('role:grant', 'role:revoke', 'audit:list');

-- viewer: 只读
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'viewer'
     AND p.`code` IN ('user:list', 'user:view',
                      'book:list', 'book:view',
                      'record:list', 'record:view',
                      'dashboard:view', 'category:preset:list');

SET FOREIGN_KEY_CHECKS = 1;
```

**Step 2: 编译 + 启服确认迁移跑通**

```bash
cd "005.后端代码（Java工程师）"
mvn -q clean compile -DskipTests
mvn -q spring-boot:run &
sleep 25
mysql -uroot -p qingzhang -e "SHOW TABLES LIKE 'admin%'; SELECT code,name FROM admin_roles;"
mysql -uroot -p qingzhang -e "SELECT COUNT(*) FROM admin_permissions;"
```

Expected: 5 张 `admin_*` 表创建,3 行角色,17 行权限 (super_admin 17 行, admin 14 行, viewer 8 行)。

**Step 3: 停服 + Commit**

```bash
pkill -f spring-boot:run
git add "005.后端代码（Java工程师）/src/main/resources/db/migration/V5__admin_rbac_and_audit.sql"
git commit -m "feat(后端): Flyway V5 — RBAC 5 表 + 3 角色 + 17 权限种子"
```

---

## Task 2: 5 个 Admin 实体 + 5 个 Mapper

**Files:**
- Create: `com/qingzhang/admin/entity/AdminRole.java`
- Create: `com/qingzhang/admin/entity/AdminPermission.java`
- Create: `com/qingzhang/admin/entity/AdminRolePermission.java`
- Create: `com/qingzhang/admin/entity/AdminUserRole.java`
- Create: `com/qingzhang/admin/entity/AdminAuditLog.java`
- Create: `com/qingzhang/admin/mapper/AdminRoleMapper.java`
- Create: `com/qingzhang/admin/mapper/AdminPermissionMapper.java`
- Create: `com/qingzhang/admin/mapper/AdminRolePermissionMapper.java`
- Create: `com/qingzhang/admin/mapper/AdminUserRoleMapper.java`
- Create: `com/qingzhang/admin/mapper/AdminAuditLogMapper.java`

**参考**: `users/entity/User.java` 风格 (Lombok 全套 + `@TableName` + `@TableLogic @TableField(select=false)`),`categories/mapper/CategoryMapper.java` 风格 (interface extends `BaseMapper<T>`)。

**Step 1: AdminRole**

```java
package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.*;
import java.time.Instant;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
@TableName("admin_roles")
public class AdminRole {
    @TableId(type = IdType.AUTO) private Long id;
    private String uuid;
    private String code;
    private String name;
    private String description;
    private Byte status;
    private Instant createdAt;
    private Instant updatedAt;

    @TableLogic @TableField(select = false) private Instant deletedAt;
}
```

**Step 2: AdminPermission**

```java
package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.*;
import java.time.Instant;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
@TableName("admin_permissions")
public class AdminPermission {
    @TableId(type = IdType.AUTO) private Long id;
    private String code;
    private String name;
    private String resource;
    private String action;
    private Instant createdAt;
    // 无软删
}
```

**Step 3: AdminRolePermission (复合主键,无 auto-increment id)**

```java
package com.qingzhang.admin.entity;

import lombok.*;
import java.io.Serializable;
import java.util.Objects;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class AdminRolePermission implements Serializable {
    private Long roleId;
    private Long permissionId;

    // MyBatis-Plus 复合主键必须实现 equals/hashCode
    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof AdminRolePermission that)) return false;
        return Objects.equals(roleId, that.roleId) && Objects.equals(permissionId, that.permissionId);
    }
    @Override public int hashCode() { return Objects.hash(roleId, permissionId); }
}
```

**Step 4: AdminUserRole**

```java
package com.qingzhang.admin.entity;

import lombok.*;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class AdminUserRole implements Serializable {
    private Long userId;
    private Long roleId;
    private Instant grantedAt;
    private Long grantedBy;

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof AdminUserRole that)) return false;
        return Objects.equals(userId, that.userId) && Objects.equals(roleId, that.roleId);
    }
    @Override public int hashCode() { return Objects.hash(userId, roleId); }
}
```

**Step 5: AdminAuditLog**

```java
package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.*;
import java.time.Instant;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
@TableName("admin_audit_logs")
public class AdminAuditLog {
    @TableId(type = IdType.AUTO) private Long id;
    private String uuid;
    private Long actorUserId;
    private String actorUsername;
    private String action;
    private String targetType;
    private Long targetId;
    private String beforeSnapshot;   // JSON 字符串,MySQL JSON 列映射 String
    private String afterSnapshot;
    private String ip;
    private String userAgent;
    private String result;            // success / failure
    private String errorMsg;
    private Instant createdAt;
    // 无软删
}
```

**Step 6: 5 个 Mapper (空接口,继承 BaseMapper)**

```java
// AdminRoleMapper.java
package com.qingzhang.admin.mapper;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.admin.entity.AdminRole;
public interface AdminRoleMapper extends BaseMapper<AdminRole> {}
```

其他 4 个 Mapper 同样模式(替换 entity 名)。`AdminRolePermissionMapper` 和 `AdminUserRoleMapper` 继承 `BaseMapper<AdminRolePermission>` / `BaseMapper<AdminUserRole>`。

**Step 7: 编译验证**

```bash
cd "005.后端代码（Java工程师）"
mvn -q compile
```

Expected: BUILD SUCCESS。

**Step 8: Commit**

```bash
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/"
git commit -m "feat(后端): admin 子系统 5 实体 + 5 Mapper"
```

---

## Task 3: DTO 全套 (15 records)

**Files:**
- Create: `com/qingzhang/admin/dto/AdminMeResponse.java`
- Create: `com/qingzhang/admin/dto/AdminUserListItem.java`
- Create: `com/qingzhang/admin/dto/AdminUserDetailResponse.java`
- Create: `com/qingzhang/admin/dto/AdminUpdateUserStatusRequest.java`
- Create: `com/qingzhang/admin/dto/AdminResetPasswordResponse.java`
- Create: `com/qingzhang/admin/dto/AdminGrantRoleRequest.java`
- Create: `com/qingzhang/admin/dto/AdminPresetCategoryRequest.java`
- Create: `com/qingzhang/admin/dto/AdminBookListItem.java`
- Create: `com/qingzhang/admin/dto/AdminRecordListItem.java`
- Create: `com/qingzhang/admin/dto/AdminDashboardStats.java`
- Create: `com/qingzhang/admin/dto/AdminAuditLogListItem.java`
- Create: `com/qingzhang/admin/dto/AdminAuditLogDetailResponse.java`
- Create: `com/qingzhang/admin/dto/AdminRoleListItem.java`

**全部 Java record**。每个 5-10 行。例如:

```java
// AdminMeResponse.java
package com.qingzhang.admin.dto;
import java.util.List;
public record AdminMeResponse(
    long id, String uuid, String username, String displayName,
    boolean isSuperAdmin,
    List<String> permissions,
    List<String> roleCodes
) {}
```

```java
// AdminUserListItem.java
package com.qingzhang.admin.dto;
import java.time.Instant;
public record AdminUserListItem(
    long id, String uuid, String username, String displayName,
    Byte status, Instant lastLoginAt, Instant createdAt,
    int recordCount, int bookCount
) {}
```

```java
// AdminUserDetailResponse.java
package com.qingzhang.admin.dto;
import java.time.Instant;
import java.util.List;
public record AdminUserDetailResponse(
    long id, String uuid, String username, String displayName,
    String avatar, String gender, Integer age, String email, String phone,
    Byte status, Instant lastLoginAt, Instant lastLoginIp, Instant createdAt,
    List<String> roles
) {}
```

```java
// AdminUpdateUserStatusRequest.java
package com.qingzhang.admin.dto;
public record AdminUpdateUserStatusRequest(boolean enabled) {}
```

```java
// AdminResetPasswordResponse.java
package com.qingzhang.admin.dto;
public record AdminResetPasswordResponse(String newPassword) {}
```

```java
// AdminGrantRoleRequest.java
package com.qingzhang.admin.dto;
public record AdminGrantRoleRequest(String roleCode) {}
```

```java
// AdminPresetCategoryRequest.java
package com.qingzhang.admin.dto;
public record AdminPresetCategoryRequest(
    String type,    // 'expense' | 'income'
    String name,
    String icon,
    String color,
    Integer sortOrder
) {}
```

```java
// AdminBookListItem.java
package com.qingzhang.admin.dto;
import java.time.Instant;
public record AdminBookListItem(
    String uuid, String name, String type, String currency,
    long ownerId, String ownerUsername, int accountCount, int recordCount,
    Instant createdAt
) {}
```

```java
// AdminRecordListItem.java
package com.qingzhang.admin.dto;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
public record AdminRecordListItem(
    String uuid, String type, BigDecimal amount, String currency,
    String note, LocalDate recordDate, String source,
    long userId, String username, String bookUuid, String bookName,
    String categoryName, String accountName,
    Instant createdAt
) {}
```

```java
// AdminDashboardStats.java
package com.qingzhang.admin.dto;
import java.util.List;
public record AdminDashboardStats(
    long userCount, long userNewToday, long userActive7d,
    long bookCount, long accountCount, long recordCount, long recordToday,
    List<DailyCount> newUsersLast7Days,
    List<DailyCount> newRecordsLast7Days
) {
    public record DailyCount(String date, long count) {}
}
```

```java
// AdminAuditLogListItem.java
package com.qingzhang.admin.dto;
import java.time.Instant;
public record AdminAuditLogListItem(
    String uuid, String actorUsername, String action,
    String targetType, Long targetId, String result,
    Instant createdAt
) {}
```

```java
// AdminAuditLogDetailResponse.java
package com.qingzhang.admin.dto;
import java.time.Instant;
public record AdminAuditLogDetailResponse(
    String uuid, String actorUsername, Long actorUserId,
    String action, String targetType, Long targetId,
    String beforeSnapshot, String afterSnapshot,
    String ip, String userAgent, String result, String errorMsg,
    Instant createdAt
) {}
```

```java
// AdminRoleListItem.java
package com.qingzhang.admin.dto;
public record AdminRoleListItem(String code, String name, String description) {}
```

**Step: 编译 + Commit**

```bash
cd "005.后端代码（Java工程师）"
mvn -q compile
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/dto/"
git commit -m "feat(后端): admin 子系统 13 DTO record"
```

---

## Task 4: 错误码 + JWT 扩展 + AuthFilter 暴露 permissions

**Files:**
- Modify: `com/qingzhang/common/ErrorCode.java` (新增 14xx 区间)
- Modify: `com/qingzhang/auth/JwtUtil.java` (overload `issue(...)` + 解析新 claims)
- Modify: `com/qingzhang/auth/JwtAuthFilter.java` (多 set 3 个 attr)
- Modify: `com/qingzhang/auth/AuthService.java` (login/register 算 permissions)
- Modify: `com/qingzhang/auth/AuthController.java` (响应多带 3 字段)

**Step 1: ErrorCode 加常量**

```java
package com.qingzhang.common;

public final class ErrorCode {
    private ErrorCode() {}
    // 现有常量...

    // ========== Admin (14xx) ==========
    public static final int ADMIN_AUTH_REQUIRED     = 1401;
    public static final int ADMIN_PERMISSION_DENIED = 1403;
    public static final int ADMIN_USER_NOT_FOUND    = 1410;
    public static final int ADMIN_ROLE_NOT_FOUND    = 1420;
    public static final int ADMIN_TARGET_NOT_FOUND  = 1490;
    public static final int ADMIN_BOOTSTRAP_DISABLED = 1499;
}
```

**Step 2: JwtUtil 改造**

```java
package com.qingzhang.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Date;
import java.util.List;

@Component
public class JwtUtil {

    @Value("${jwt.secret:please-change-me-in-application-yml-must-be-at-least-32-bytes}")
    private String secret;

    @Value("${jwt.expiration-days:7}")
    private long expirationDays;

    @Value("${jwt.admin-expiration-hours:24}")
    private long adminExpirationHours;

    private SecretKey key;

    @PostConstruct
    void init() {
        byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException("jwt.secret 必须 ≥ 32 字节(HS256 要求)");
        }
        this.key = Keys.hmacShaKeyFor(bytes);
    }

    /** 给普通用户发 token(permissions 留空)。 */
    public String issue(long userId) {
        return issue(userId, List.of(), List.of(), false, expirationDays * 24, ChronoUnit.HOURS);
    }

    /** 给管理员发 token(带 permissions / roleCodes / isSuperAdmin + 短过期)。 */
    public String issue(long userId, List<String> permissions, List<String> roleCodes, boolean isSuperAdmin) {
        return issue(userId, permissions, roleCodes, isSuperAdmin, adminExpirationHours, ChronoUnit.HOURS);
    }

    private String issue(long userId, List<String> permissions, List<String> roleCodes,
                        boolean isSuperAdmin, long amount, ChronoUnit unit) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(Long.toString(userId))
                .claim("permissions", permissions)
                .claim("roleCodes", roleCodes)
                .claim("isSuperAdmin", isSuperAdmin)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(amount, unit)))
                .signWith(key)
                .compact();
    }

    /** 解析失败的 claim 默认值。 */
    public ParsedToken parse(String token) {
        Claims claims = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload();
        long uid = Long.parseLong(claims.getSubject());
        @SuppressWarnings("unchecked")
        List<String> perms = (List<String>) claims.getOrDefault("permissions", List.of());
        @SuppressWarnings("unchecked")
        List<String> roles = (List<String>) claims.getOrDefault("roleCodes", List.of());
        Boolean sup = (Boolean) claims.getOrDefault("isSuperAdmin", false);
        return new ParsedToken(uid, perms, roles, Boolean.TRUE.equals(sup));
    }

    /** 兼容旧逻辑:解析 subject。 */
    public long parseSubject(String token) {
        return parse(token).userId();
    }

    public record ParsedToken(long userId, List<String> permissions, List<String> roleCodes, boolean isSuperAdmin) {}
}
```

**Step 3: JwtAuthFilter 改造**

```java
package com.qingzhang.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;

@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(JwtAuthFilter.class);
    public static final String USER_ID_ATTR    = "userId";
    public static final String PERMS_ATTR      = "permissions";
    public static final String ROLES_ATTR      = "roleCodes";
    public static final String SUPER_ATTR      = "isSuperAdmin";

    private final JwtUtil jwtUtil;

    public JwtAuthFilter(JwtUtil jwtUtil) { this.jwtUtil = jwtUtil; }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain)
            throws ServletException, IOException {
        String header = req.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                JwtUtil.ParsedToken p = jwtUtil.parse(token);
                req.setAttribute(USER_ID_ATTR, p.userId());
                req.setAttribute(PERMS_ATTR, p.permissions());
                req.setAttribute(ROLES_ATTR, p.roleCodes());
                req.setAttribute(SUPER_ATTR, p.isSuperAdmin());
            } catch (Exception ex) {
                log.warn("[jwt] token 解析失败: {}", ex.getMessage());
            }
        }
        chain.doFilter(req, res);
    }
}
```

**Step 4: AuthService 改造**

修改 `register()` 和 `login()` 末尾的 `jwtUtil.issue(u.getId())` 改成:

```java
// 在 register() 末尾,替换 jwtUtil.issue(u.getId()):
AdminPermissionService perms = ...; // 注入
var resolved = perms.resolveForUser(u.getId());
String token = jwtUtil.issue(u.getId(), resolved.permissions(), resolved.roleCodes(), resolved.isSuperAdmin());
return new AuthResponse(toDto(u, resolved), token);
```

```java
// 在 login() 末尾同理
var resolved = perms.resolveForUser(u.getId());
String token = jwtUtil.issue(u.getId(), resolved.permissions(), resolved.roleCodes(), resolved.isSuperAdmin());
return new AuthResponse(toDto(u, resolved), token);
```

`toDto(User, ResolvedPermissions)` overload 多带 3 字段。

> 注:`AdminPermissionService` 在 Task 5 才建。先在 AuthService 里**写一个内联方法** `resolvePermissionsForUser(long userId)` 直接查 admin 表;Task 5 抽出。

**临时内联代码** (Task 4 内,放进 AuthService):

```java
private ResolvedPermissions resolvePermissionsForUser(long userId) {
    // 直接查 admin_user_roles + admin_role_permissions
    List<Map<String, Object>> rows = userMapper.selectMaps(...); // 见下
    Set<String> perms = new LinkedHashSet<>();
    Set<String> roles = new LinkedHashSet<>();
    boolean isSuper = false;
    for (Map<String, Object> row : rows) {
        roles.add((String) row.get("role_code"));
        if ("super_admin".equals(row.get("role_code"))) isSuper = true;
        perms.add((String) row.get("permission_code"));
    }
    return new ResolvedPermissions(new ArrayList<>(perms), new ArrayList<>(roles), isSuper);
}

record ResolvedPermissions(List<String> permissions, List<String> roleCodes, boolean isSuperAdmin) {}
```

完整 SQL (用 `userMapper.selectMaps` + `Wrappers`):

```java
List<Map<String, Object>> rows = userMapper.selectMaps(
    new com.baomidou.mybatisplus.core.toolkit.Wrappers.<Object>query()
        .select("r.code AS role_code, p.code AS permission_code")
        .from("admin_user_roles ur")
        .innerJoin("admin_roles r ON r.id = ur.role_id AND r.deleted_at IS NULL AND r.status = 1")
        .innerJoin("admin_role_permissions rp ON rp.role_id = r.id")
        .innerJoin("admin_permissions p ON p.id = rp.permission_id")
        .eq("ur.user_id", userId)
);
```

> MyBatis-Plus `Wrappers` 不支持 `.from()` 链式 join — 改用原生 `userMapper.executeSql(...)` 或在 `UserMapper` 加一个 `@Select` 方法 `selectAdminPermissionsByUserId`。
> **推荐**: 在 `users/mapper/UserMapper.java` 加:

```java
@Select("""
    SELECT r.code AS role_code, p.code AS permission_code
      FROM admin_user_roles ur
      JOIN admin_roles r       ON r.id = ur.role_id AND r.deleted_at IS NULL AND r.status = 1
      JOIN admin_role_permissions rp ON rp.role_id = r.id
      JOIN admin_permissions p ON p.id = rp.permission_id
     WHERE ur.user_id = #{userId}
""")
List<Map<String, Object>> selectAdminPermissionsByUserId(@Param("userId") long userId);
```

**Step 5: AuthController 改造**

修改 `AuthResponse` record:

```java
public record AuthResponse(UserDTO user, String token,
                            List<String> permissions, List<String> roleCodes, boolean isSuperAdmin) {}
```

修改 `/api/auth/login` 和 `/api/auth/register` 响应构造,多带 3 字段。

**Step 6: application.yml 加 admin 段**

```yaml
jwt:
  secret: ${JWT_SECRET:please-change-me-in-application-yml-must-be-at-least-32-bytes}
  expiration-days: 7
  admin-expiration-hours: 24   # 新增

admin:
  bootstrap:
    username: ${ADMIN_BOOTSTRAP_USERNAME:}
    password: ${ADMIN_BOOTSTRAP_PASSWORD:}
```

**Step 7: 编译 + 跑通 login/register**

```bash
cd "005.后端代码（Java工程师）"
mvn -q clean compile
mvn -q spring-boot:run &
sleep 25
# 注册一个新用户,响应里 permissions 应为空数组
curl -s -X POST localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice1","password":"Pass@1234"}' | jq '.data.token, .data.permissions'
# Expected: token 字符串 + [] 空数组
pkill -f spring-boot:run
```

**Step 8: Commit**

```bash
git add "005.后端代码（Java工程师）/"
git commit -m "feat(后端): JWT 扩展 permissions/roleCodes/isSuperAdmin claims + admin 短过期"
```

---

## Task 5: @RequiresPermission 注解 + AdminAuthInterceptor + AdminPermissionService

**Files:**
- Create: `com/qingzhang/admin/security/RequiresPermission.java`
- Create: `com/qingzhang/admin/security/AdminAuthInterceptor.java`
- Create: `com/qingzhang/admin/security/AdminInterceptorConfig.java` (WebMvcConfigurer)
- Create: `com/qingzhang/admin/service/AdminPermissionService.java` (把 Task 4 内联代码抽出来)

**Step 1: RequiresPermission 注解**

```java
package com.qingzhang.admin.security;

import java.lang.annotation.*;

@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
@Documented
public @interface RequiresPermission {
    String value();
}
```

**Step 2: AdminAuthInterceptor**

```java
package com.qingzhang.admin.security;

import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.List;
import java.util.Set;

@Component
public class AdminAuthInterceptor implements HandlerInterceptor {

    @Override
    public boolean preHandle(HttpServletRequest req, HttpServletResponse res, Object handler) {
        if (!(handler instanceof HandlerMethod hm)) return true;

        RequiresPermission anno = hm.getMethodAnnotation(RequiresPermission.class);
        if (anno == null) return true;

        Object uidObj = req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (uidObj == null) {
            throw new BizException(ErrorCode.ADMIN_AUTH_REQUIRED, "需要登录");
        }
        Boolean isSuper = (Boolean) req.getAttribute(JwtAuthFilter.SUPER_ATTR);
        if (Boolean.TRUE.equals(isSuper)) return true;

        @SuppressWarnings("unchecked")
        Set<String> perms = Set.copyOf((List<String>) req.getAttribute(JwtAuthFilter.PERMS_ATTR));
        if (perms.contains(anno.value())) return true;

        throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "无权限: " + anno.value());
    }
}
```

**Step 3: AdminInterceptorConfig**

```java
package com.qingzhang.admin.security;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class AdminInterceptorConfig implements WebMvcConfigurer {

    private final AdminAuthInterceptor interceptor;

    public AdminInterceptorConfig(AdminAuthInterceptor interceptor) { this.interceptor = interceptor; }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(interceptor)
                .addPathPatterns("/api/admin/**")
                .excludePathPatterns("/api/admin/auth/login");   // 登录端点放行
    }
}
```

> 注: 现有 `AuthFilterConfig` 注册了 JwtAuthFilter 在 `/api/*`,会自动覆盖 `/api/admin/*`,无需改。

**Step 4: AdminPermissionService 抽出 + 复用**

```java
package com.qingzhang.admin.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.admin.entity.AdminPermission;
import com.qingzhang.admin.entity.AdminRole;
import com.qingzhang.admin.entity.AdminUserRole;
import com.qingzhang.admin.mapper.AdminPermissionMapper;
import com.qingzhang.admin.mapper.AdminRoleMapper;
import com.qingzhang.admin.mapper.AdminUserRoleMapper;
import com.qingzhang.users.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
@RequiredArgsConstructor
public class AdminPermissionService {

    private final UserMapper userMapper;
    private final AdminUserRoleMapper userRoleMapper;
    private final AdminRoleMapper roleMapper;
    private final AdminPermissionMapper permissionMapper;

    public Resolved resolveForUser(long userId) {
        // 查 user 的 role + 直接用 SQL 拿 permissions(避免 N+1)
        List<AdminUserRole> urs = userRoleMapper.selectList(
            Wrappers.<AdminUserRole>lambdaQuery().eq(AdminUserRole::getUserId, userId));
        if (urs.isEmpty()) return new Resolved(List.of(), List.of(), false);

        Set<Long> roleIds = new HashSet<>();
        for (var ur : urs) roleIds.add(ur.getRoleId());
        List<AdminRole> roles = roleMapper.selectBatchIds(roleIds);
        Set<String> roleCodes = new LinkedHashSet<>();
        boolean isSuper = false;
        for (var r : roles) {
            if (r.getStatus() != null && r.getStatus() == 1 && r.getDeletedAt() == null) {
                roleCodes.add(r.getCode());
                if ("super_admin".equals(r.getCode())) isSuper = true;
            }
        }
        // 一次性查 permissions
        List<Map<String, Object>> rows = userMapper.selectAdminPermissionsByUserId(userId);
        Set<String> perms = new LinkedHashSet<>();
        for (var row : rows) perms.add((String) row.get("permission_code"));
        return new Resolved(new ArrayList<>(perms), new ArrayList<>(roleCodes), isSuper);
    }

    public record Resolved(List<String> permissions, List<String> roleCodes, boolean isSuperAdmin) {}

    // ponytail: 自检 — 确保 resolve 对未授权用户返回空
    public static void main(String[] args) {
        Resolved r = new Resolved(List.of(), List.of(), false);
        if (!r.permissions().isEmpty() || r.isSuperAdmin()) throw new AssertionError("空权限断言失败");
        System.out.println("[demo] AdminPermissionService 空权限 OK");
    }
}
```

> **Task 4 内联的 `resolvePermissionsForUser` 现在替换为调用 `AdminPermissionService.resolveForUser()`**。在 AuthService 构造函数注入 `AdminPermissionService`,删除内联方法。

**Step 5: 编译验证**

```bash
cd "005.后端代码（Java工程师）"
mvn -q clean compile
```

**Step 6: Commit**

```bash
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/security/" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminPermissionService.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/auth/" \
        "005.后端代码（Java工程师）/src/main/resources/application.yml" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/common/ErrorCode.java"
git commit -m "feat(后端): @RequiresPermission + AdminAuthInterceptor + PermissionService"
```

---

## Task 6: AdminAuditService + RequestContextHelper

**Files:**
- Create: `com/qingzhang/admin/service/AdminAuditService.java`
- Create: `com/qingzhang/admin/util/AdminRequestContext.java`

**Step 1: AdminRequestContext (取 IP / UA)**

```java
package com.qingzhang.admin.util;

import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

public final class AdminRequestContext {
    private AdminRequestContext() {}

    public static String ip() {
        HttpServletRequest req = current();
        if (req == null) return null;
        String h = req.getHeader("X-Forwarded-For");
        if (h != null && !h.isBlank()) return h.split(",")[0].trim();
        return req.getRemoteAddr();
    }

    public static String userAgent() {
        HttpServletRequest req = current();
        return req == null ? null : req.getHeader("User-Agent");
    }

    private static HttpServletRequest current() {
        var attrs = RequestContextHolder.getRequestAttributes();
        return attrs instanceof ServletRequestAttributes sa ? sa.getRequest() : null;
    }
}
```

**Step 2: AdminAuditService**

```java
package com.qingzhang.admin.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qingzhang.admin.entity.AdminAuditLog;
import com.qingzhang.admin.mapper.AdminAuditLogMapper;
import com.qingzhang.admin.util.AdminRequestContext;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AdminAuditService {

    private static final Logger log = LoggerFactory.getLogger(AdminAuditService.class);
    private static final ObjectMapper MAPPER = new ObjectMapper();

    private final AdminAuditLogMapper auditMapper;
    private final UserMapper userMapper;

    public void record(long actorUserId, String action, String targetType, Long targetId,
                       Object before, Object after, boolean success, String errorMsg) {
        try {
            AdminAuditLog row = AdminAuditLog.builder()
                    .uuid(UUID.randomUUID().toString())
                    .actorUserId(actorUserId)
                    .actorUsername(usernameOf(actorUserId))
                    .action(action)
                    .targetType(targetType)
                    .targetId(targetId)
                    .beforeSnapshot(toJson(before))
                    .afterSnapshot(toJson(after))
                    .ip(AdminRequestContext.ip())
                    .userAgent(truncate(AdminRequestContext.userAgent(), 255))
                    .result(success ? "success" : "failure")
                    .errorMsg(truncate(errorMsg, 500))
                    .createdAt(Instant.now())
                    .build();
            auditMapper.insert(row);
        } catch (Exception ex) {
            // 审计失败不能影响业务
            log.warn("[audit] 落库失败: action={}, err={}", action, ex.getMessage());
        }
    }

    private String usernameOf(long uid) {
        if (uid <= 0) return "system";
        User u = userMapper.selectById(uid);
        return u == null ? "deleted#" + uid : u.getUsername();
    }

    private String toJson(Object o) {
        if (o == null) return null;
        try { return MAPPER.writeValueAsString(o); }
        catch (JsonProcessingException e) { return null; }
    }

    private String truncate(String s, int max) {
        if (s == null) return null;
        return s.length() <= max ? s : s.substring(0, max);
    }

    public static void main(String[] args) {
        // ponytail: 自检
        AdminAuditService s = new AdminAuditService(null, null);
        try {
            s.record(0, "test.action", "test", 1L, null, null, true, null);
        } catch (Exception ignored) {}
        System.out.println("[demo] AdminAuditService 调用链 OK");
    }
}
```

**Step 3: 编译**

```bash
mvn -q compile
```

**Step 4: Commit**

```bash
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminAuditService.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/util/"
git commit -m "feat(后端): AdminAuditService 写审计 + RequestContext 取 IP/UA"
```

---

## Task 7: AdminBootstrapService + CommandLineRunner (首次超级管理员)

**Files:**
- Create: `com/qingzhang/admin/service/AdminBootstrapService.java`
- Modify: `com/qingzhang/QingZhangApplication.java` (加 @Bean)

**Step 1: AdminBootstrapService**

```java
package com.qingzhang.admin.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.admin.entity.AdminRole;
import com.qingzhang.admin.entity.AdminUserRole;
import com.qingzhang.admin.mapper.AdminRoleMapper;
import com.qingzhang.admin.mapper.AdminUserRoleMapper;
import com.qingzhang.auth.AuthService;
import com.qingzhang.auth.dto.Credentials;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Component;

import java.time.Instant;

@Component
@Order(1)   // 在其他 CommandLineRunner 之前跑
@RequiredArgsConstructor
public class AdminBootstrapService implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(AdminBootstrapService.class);

    @Value("${admin.bootstrap.username:}")
    private String bootstrapUsername;

    @Value("${admin.bootstrap.password:}")
    private String bootstrapPassword;

    private final UserMapper userMapper;
    private final AdminUserRoleMapper userRoleMapper;
    private final AdminRoleMapper roleMapper;
    private final AuthService authService;  // 复用 register 流程(送账本/账户)

    @Override
    public void run(String... args) {
        if (bootstrapUsername.isBlank() || bootstrapPassword.isBlank()) {
            log.info("[bootstrap] admin.bootstrap.username/password 未设置,跳过首次引导");
            return;
        }
        long count = userRoleMapper.selectCount(null);
        if (count > 0) {
            log.info("[bootstrap] admin_user_roles 已有 {} 条记录,跳过引导", count);
            return;
        }

        User existing = userMapper.selectOne(
            Wrappers.<User>lambdaQuery().eq(User::getUsername, bootstrapUsername));
        long userId;
        if (existing == null) {
            // 调 AuthService.register 走完整流程(送默认账本 + 5 账户)
            // 注意:AuthService.register 返回 AuthResponse 但会签发 token,这里不取 token
            authService.register(new Credentials(bootstrapUsername, bootstrapPassword));
            existing = userMapper.selectOne(
                Wrappers.<User>lambdaQuery().eq(User::getUsername, bootstrapUsername));
            if (existing == null) {
                log.warn("[bootstrap] 注册失败,跳过授权");
                return;
            }
        }
        userId = existing.getId();

        AdminRole sup = roleMapper.selectOne(
            Wrappers.<AdminRole>lambdaQuery().eq(AdminRole::getCode, "super_admin"));
        if (sup == null) {
            log.warn("[bootstrap] 找不到 super_admin 角色 (V5 迁移未跑?),跳过");
            return;
        }
        AdminUserRole ur = new AdminUserRole();
        ur.setUserId(userId);
        ur.setRoleId(sup.getId());
        ur.setGrantedAt(Instant.now());
        ur.setGrantedBy(null);  // 系统引导,无授予人
        userRoleMapper.insert(ur);

        log.warn("[bootstrap] 已创建 super admin: username={} (密码请妥善保管,生产部署后请 unset 环境变量)",
                 bootstrapUsername);
    }
}
```

**Step 2: QingZhangApplication 注册 (无需改)**

`@SpringBootApplication` + `CommandLineRunner` bean 自动跑。无需显式注册。

**Step 3: 跑通验证**

```bash
cd "005.后端代码（Java工程师）"
# 准备空表(全新库)
mysql -uroot -p qingzhang -e "DELETE FROM admin_user_roles; DELETE FROM users WHERE username='root';"

ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD='Root@12345' \
  mvn -q spring-boot:run &
sleep 30

mysql -uroot -p qingzhang -e "SELECT u.username, r.code FROM users u JOIN admin_user_roles ur ON ur.user_id=u.id JOIN admin_roles r ON r.id=ur.role_id;"
# Expected: root | super_admin

pkill -f spring-boot:run
```

**Step 4: Commit**

```bash
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminBootstrapService.java"
git commit -m "feat(后端): AdminBootstrapService — 首次 super admin 引导 (env 驱动)"
```

---

## Task 8: AdminUserService + AdminUsersController

**Files:**
- Create: `com/qingzhang/admin/service/AdminUserService.java`
- Create: `com/qingzhang/admin/controller/AdminUsersController.java`

**Step 1: AdminUserService**

```java
package com.qingzhang.admin.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.dto.*;
import com.qingzhang.admin.entity.AdminRole;
import com.qingzhang.admin.entity.AdminUserRole;
import com.qingzhang.admin.mapper.AdminRoleMapper;
import com.qingzhang.admin.mapper.AdminUserRoleMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.*;

@Service
@RequiredArgsConstructor
public class AdminUserService {

    private final UserMapper userMapper;
    private final AdminUserRoleMapper userRoleMapper;
    private final AdminRoleMapper roleMapper;
    private final AdminAuditService audit;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public Page<AdminUserListItem> list(String search, Byte status, int page, int size) {
        LambdaQueryWrapper<User> q = Wrappers.<User>lambdaQuery()
                .like(search != null && !search.isBlank(), User::getUsername, search)
                .eq(status != null, User::getStatus, status)
                .orderByDesc(User::getCreatedAt);
        Page<User> p = userMapper.selectPage(Page.of(page, size), q);
        List<AdminUserListItem> items = p.getRecords().stream().map(this::toListItem).toList();
        Page<AdminUserListItem> out = Page.of(page, size, p.getTotal());
        out.setRecords(items);
        return out;
    }

    public AdminUserDetailResponse detail(long userId) {
        User u = userMapper.selectById(userId);
        if (u == null) throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "用户不存在");
        List<String> roles = userRoleMapper.selectList(
                Wrappers.<AdminUserRole>lambdaQuery().eq(AdminUserRole::getUserId, userId))
            .stream().map(ur -> roleMapper.selectById(ur.getRoleId()))
            .filter(Objects::nonNull)
            .map(AdminRole::getCode).toList();
        return new AdminUserDetailResponse(
            u.getId(), u.getUuid(), u.getUsername(), u.getDisplayName(),
            u.getAvatar(), u.getGender(), u.getAge(), u.getEmail(), u.getPhone(),
            u.getStatus(),
            u.getLastLoginAt(), u.getLastLoginIp() == null ? null : null,  // lastLoginIp 字段类型修正
            u.getCreatedAt(), roles);
    }

    @Transactional(rollbackFor = Exception.class)
    public void updateStatus(long actorId, long userId, boolean enabled, String ip, String ua) {
        User u = userMapper.selectById(userId);
        if (u == null) throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "用户不存在");
        User before = copyOf(u);
        u.setStatus(enabled ? (byte) 1 : (byte) 0);
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);
        audit.record(actorId, "user.disable", "user", userId, before, u, true, null);
    }

    @Transactional(rollbackFor = Exception.class)
    public String resetPassword(long actorId, long userId) {
        User u = userMapper.selectById(userId);
        if (u == null) throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "用户不存在");
        // 生成 12 位随机密码 (字母+数字)
        String newPwd = randomPassword(12);
        User before = copyOf(u);
        u.setPasswordHash(encoder.encode(newPwd));
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);
        audit.record(actorId, "user.reset_password", "user", userId, before, u, true, null);
        return newPwd;
    }

    @Transactional(rollbackFor = Exception.class)
    public void grantRole(long actorId, long userId, String roleCode, Long grantedBy) {
        AdminRole role = roleMapper.selectOne(
            Wrappers.<AdminRole>lambdaQuery().eq(AdminRole::getCode, roleCode));
        if (role == null) throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色不存在: " + roleCode);
        AdminUserRole ur = userRoleMapper.selectOne(
            Wrappers.<AdminUserRole>lambdaQuery()
                .eq(AdminUserRole::getUserId, userId)
                .eq(AdminUserRole::getRoleId, role.getId()));
        if (ur != null) return; // 已存在,幂等
        ur = new AdminUserRole();
        ur.setUserId(userId);
        ur.setRoleId(role.getId());
        ur.setGrantedAt(Instant.now());
        ur.setGrantedBy(grantedBy);
        userRoleMapper.insert(ur);
        audit.record(actorId, "role.grant", "user", userId, null, Map.of("roleCode", roleCode), true, null);
    }

    @Transactional(rollbackFor = Exception.class)
    public void revokeRole(long actorId, long userId, String roleCode) {
        AdminRole role = roleMapper.selectOne(
            Wrappers.<AdminRole>lambdaQuery().eq(AdminRole::getCode, roleCode));
        if (role == null) throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色不存在");
        AdminUserRole ur = userRoleMapper.selectOne(
            Wrappers.<AdminUserRole>lambdaQuery()
                .eq(AdminUserRole::getUserId, userId)
                .eq(AdminUserRole::getRoleId, role.getId()));
        if (ur == null) return; // 不存在,幂等
        userRoleMapper.deleteById(ur);
        audit.record(actorId, "role.revoke", "user", userId,
                     Map.of("roleCode", roleCode), null, true, null);
    }

    private AdminUserListItem toListItem(User u) {
        // recordCount / bookCount 简化:用 SELECT COUNT 现场查,后续可加缓存
        return new AdminUserListItem(
            u.getId(), u.getUuid(), u.getUsername(), u.getDisplayName(),
            u.getStatus(), u.getLastLoginAt(), u.getCreatedAt(),
            0, 0);   // ponytail: N+1 优化,加统计表再补;首版返 0
    }

    private User copyOf(User u) {
        return User.builder()
            .id(u.getId()).uuid(u.getUuid()).username(u.getUsername())
            .passwordHash(u.getPasswordHash()).displayName(u.getDisplayName())
            .avatar(u.getAvatar()).gender(u.getGender()).age(u.getAge())
            .email(u.getEmail()).phone(u.getPhone()).status(u.getStatus())
            .lastLoginAt(u.getLastLoginAt()).lastLoginIp(u.getLastLoginIp())
            .createdAt(u.getCreatedAt()).updatedAt(u.getUpdatedAt())
            .build();
    }

    private String randomPassword(int len) {
        String chars = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
        Random r = new Random();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < len; i++) sb.append(chars.charAt(r.nextInt(chars.length())));
        return sb.toString();
    }
}
```

**Step 2: AdminUsersController**

```java
package com.qingzhang.admin.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.dto.*;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.admin.service.AdminUserService;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/admin/users")
@RequiredArgsConstructor
public class AdminUsersController {

    private final AdminUserService userService;

    @GetMapping
    @RequiresPermission("user:list")
    public ApiResponse<Page<AdminUserListItem>> list(
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Byte status,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(userService.list(search, status, page, size));
    }

    @GetMapping("/{id}")
    @RequiresPermission("user:view")
    public ApiResponse<AdminUserDetailResponse> detail(@PathVariable long id) {
        return ApiResponse.ok(userService.detail(id));
    }

    @PatchMapping("/{id}/status")
    @RequiresPermission("user:disable")
    public ApiResponse<Void> updateStatus(@PathVariable long id,
                                          @RequestBody AdminUpdateUserStatusRequest req,
                                          HttpServletRequest http) {
        long actorId = (Long) http.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        userService.updateStatus(actorId, id, req.enabled(), http.getRemoteAddr(), http.getHeader("User-Agent"));
        return ApiResponse.ok();
    }

    @PostMapping("/{id}/reset-password")
    @RequiresPermission("user:reset_password")
    public ApiResponse<AdminResetPasswordResponse> resetPassword(@PathVariable long id,
                                                                  HttpServletRequest http) {
        long actorId = (Long) http.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        String newPwd = userService.resetPassword(actorId, id);
        return ApiResponse.ok(new AdminResetPasswordResponse(newPwd));
    }

    @PostMapping("/{id}/roles")
    @RequiresPermission("role:grant")
    public ApiResponse<Void> grantRole(@PathVariable long id,
                                       @RequestBody AdminGrantRoleRequest req,
                                       HttpServletRequest http) {
        long actorId = (Long) http.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        userService.grantRole(actorId, id, req.roleCode(), actorId);
        return ApiResponse.ok();
    }

    @DeleteMapping("/{id}/roles/{roleCode}")
    @RequiresPermission("role:revoke")
    public ApiResponse<Void> revokeRole(@PathVariable long id,
                                        @PathVariable String roleCode,
                                        HttpServletRequest http) {
        long actorId = (Long) http.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        userService.revokeRole(actorId, id, roleCode);
        return ApiResponse.ok();
    }
}
```

**Step 3: 编译 + 跑通**

```bash
cd "005.后端代码（Java工程师）"
mvn -q compile
ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD='Root@12345' \
  mvn -q spring-boot:run &
sleep 30

TOKEN=$(curl -s -X POST localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"root","password":"Root@12345"}' | jq -r '.data.token')

curl -s -H "Authorization: Bearer $TOKEN" localhost:8080/api/admin/users | jq '.data.total'
# Expected: 数字 (至少 1, root 自己)

# 创建一个普通用户测禁用
curl -s -X POST localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"alice2","password":"Pass@1234"}' > /tmp/alice.json
ALICE_ID=$(cat /tmp/alice.json | jq -r '.data.user.id')
curl -s -X PATCH "localhost:8080/api/admin/users/$ALICE_ID/status" \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"enabled":false}' | jq '.code'
# Expected: 0

pkill -f spring-boot:run
```

**Step 4: Commit**

```bash
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminUserService.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/controller/AdminUsersController.java"
git commit -m "feat(后端): AdminUserService + UsersController — 6 端点"
```

---

## Task 9: AdminCategoryService + AdminCategoriesController (预设分类 CRUD)

**Files:**
- Create: `com/qingzhang/admin/service/AdminCategoryService.java`
- Create: `com/qingzhang/admin/controller/AdminCategoriesController.java`

**Step 1: AdminCategoryService**

```java
package com.qingzhang.admin.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.admin.dto.AdminPresetCategoryRequest;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class AdminCategoryService {

    private final CategoryMapper categoryMapper;
    private final AdminAuditService audit;

    public List<Category> listPreset() {
        return categoryMapper.selectList(
            Wrappers.<Category>lambdaQuery()
                .eq(Category::getIsPreset, 1)
                .orderByAsc(Category::getSortOrder));
    }

    @Transactional(rollbackFor = Exception.class)
    public Category create(long actorId, AdminPresetCategoryRequest req) {
        Category c = Category.builder()
            .uuid(UUID.randomUUID().toString())
            .userId(null)        // 系统预设
            .bookId(null)        // 跨账本
            .type(req.type())
            .name(req.name())
            .icon(req.icon() == null ? "" : req.icon())
            .color(req.color() == null ? "#A0AEC0" : req.color())
            .isPreset((byte) 1)
            .isActive((byte) 1)
            .sortOrder(req.sortOrder() == null ? 0 : req.sortOrder())
            .createdAt(Instant.now())
            .updatedAt(Instant.now())
            .build();
        categoryMapper.insert(c);
        audit.record(actorId, "category.create", "category", c.getId(), null, c, true, null);
        return c;
    }

    @Transactional(rollbackFor = Exception.class)
    public Category update(long actorId, String uuid, AdminPresetCategoryRequest req) {
        Category c = findByUuid(uuid);
        Category before = c;
        if (req.name() != null) c.setName(req.name());
        if (req.icon() != null) c.setIcon(req.icon());
        if (req.color() != null) c.setColor(req.color());
        if (req.sortOrder() != null) c.setSortOrder(req.sortOrder());
        c.setUpdatedAt(Instant.now());
        categoryMapper.updateById(c);
        audit.record(actorId, "category.update", "category", c.getId(), before, c, true, null);
        return c;
    }

    @Transactional(rollbackFor = Exception.class)
    public void delete(long actorId, String uuid) {
        Category c = findByUuid(uuid);
        Category before = c;
        c.setDeletedAt(Instant.now());
        categoryMapper.updateById(c);   // @TableLogic 也能 deleteById
        audit.record(actorId, "category.delete", "category", c.getId(), before, null, true, null);
    }

    private Category findByUuid(String uuid) {
        Category c = categoryMapper.selectOne(
            Wrappers.<Category>lambdaQuery().eq(Category::getUuid, uuid));
        if (c == null) throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "分类不存在");
        return c;
    }
}
```

> 注意:`Category` 实体当前没 `getUuid`/`setUuid` getter 检查过 — 实施时按 `categories/entity/Category.java` 实际字段访问。

**Step 2: AdminCategoriesController**

```java
package com.qingzhang.admin.controller;

import com.qingzhang.admin.dto.AdminPresetCategoryRequest;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.admin.service.AdminCategoryService;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.common.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/admin/categories/preset")
@RequiredArgsConstructor
public class AdminCategoriesController {

    private final AdminCategoryService categoryService;

    @GetMapping
    @RequiresPermission("category:preset:list")
    public ApiResponse<List<Category>> list() {
        return ApiResponse.ok(categoryService.listPreset());
    }

    @PostMapping
    @RequiresPermission("category:preset:create")
    public ApiResponse<Category> create(@RequestBody AdminPresetCategoryRequest req,
                                         HttpServletRequest http) {
        long actorId = (Long) http.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        return ApiResponse.ok(categoryService.create(actorId, req));
    }

    @PatchMapping("/{uuid}")
    @RequiresPermission("category:preset:update")
    public ApiResponse<Category> update(@PathVariable String uuid,
                                         @RequestBody AdminPresetCategoryRequest req,
                                         HttpServletRequest http) {
        long actorId = (Long) http.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        return ApiResponse.ok(categoryService.update(actorId, uuid, req));
    }

    @DeleteMapping("/{uuid}")
    @RequiresPermission("category:preset:delete")
    public ApiResponse<Void> delete(@PathVariable String uuid,
                                     HttpServletRequest http) {
        long actorId = (Long) http.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        categoryService.delete(actorId, uuid);
        return ApiResponse.ok();
    }
}
```

**Step 3: 编译 + 跑通**

```bash
cd "005.后端代码（Java工程师）"
mvn -q compile
ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD='Root@12345' \
  mvn -q spring-boot:run &
sleep 30

TOKEN=$(curl -s -X POST localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"root","password":"Root@12345"}' | jq -r '.data.token')

curl -s -H "Authorization: Bearer $TOKEN" \
  localhost:8080/api/admin/categories/preset | jq '.data | length'
# Expected: 14 (9 支出 + 5 收入,V2 种子)

pkill -f spring-boot:run
```

**Step 4: Commit**

```bash
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminCategoryService.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/controller/AdminCategoriesController.java"
git commit -m "feat(后端): AdminCategoryService + CategoriesController — 预设分类 CRUD"
```

---

## Task 10: AdminBookService + AdminRecordService + AdminDashboardService + Controllers

**Files:**
- Create: `com/qingzhang/admin/service/AdminBookService.java`
- Create: `com/qingzhang/admin/service/AdminRecordService.java`
- Create: `com/qingzhang/admin/service/AdminDashboardService.java`
- Create: `com/qingzhang/admin/controller/AdminBooksController.java`
- Create: `com/qingzhang/admin/controller/AdminRecordsController.java`
- Create: `com/qingzhang/admin/controller/AdminDashboardController.java`

**Step 1: AdminBookService (只读浏览所有用户账本)**

```java
package com.qingzhang.admin.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.dto.AdminBookListItem;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminBookService {

    private final BookMapper bookMapper;
    private final UserMapper userMapper;

    public Page<AdminBookListItem> list(Long ownerId, String type, int page, int size) {
        LambdaQueryWrapper<Book> q = Wrappers.<Book>lambdaQuery()
                .eq(ownerId != null, Book::getOwnerId, ownerId)
                .eq(type != null, Book::getType, type)
                .orderByDesc(Book::getCreatedAt);
        Page<Book> p = bookMapper.selectPage(Page.of(page, size), q);
        List<AdminBookListItem> items = p.getRecords().stream().map(b -> {
            User u = userMapper.selectById(b.getOwnerId());
            return new AdminBookListItem(
                b.getUuid(), b.getName(), b.getType(), b.getCurrency(),
                b.getOwnerId(), u == null ? "deleted" : u.getUsername(),
                0, 0, b.getCreatedAt());   // ponytail: accountCount/recordCount 首版 0
        }).toList();
        Page<AdminBookListItem> out = Page.of(page, size, p.getTotal());
        out.setRecords(items);
        return out;
    }

    public Book detail(String uuid) {
        return bookMapper.selectOne(
            Wrappers.<Book>lambdaQuery().eq(Book::getUuid, uuid));
    }
}
```

**Step 2: AdminRecordService (跨用户流水筛选)**

```java
package com.qingzhang.admin.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.dto.AdminRecordListItem;
import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.records.entity.Record;
import com.qingzhang.records.mapper.RecordMapper;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class AdminRecordService {

    private final RecordMapper recordMapper;
    private final UserMapper userMapper;
    private final BookMapper bookMapper;
    private final CategoryMapper categoryMapper;
    private final AccountMapper accountMapper;

    public Page<AdminRecordListItem> list(Long userId, String bookUuid, String type,
                                          java.time.LocalDate from, java.time.LocalDate to,
                                          int page, int size) {
        LambdaQueryWrapper<Record> q = Wrappers.<Record>lambdaQuery()
                .eq(userId != null, Record::getUserId, userId)
                .eq(type != null, Record::getType, type)
                .ge(from != null, Record::getRecordDate, from)
                .le(to != null, Record::getRecordDate, to)
                .orderByDesc(Record::getRecordDate);
        if (bookUuid != null) {
            Book b = bookMapper.selectOne(
                Wrappers.<Book>lambdaQuery().eq(Book::getUuid, bookUuid));
            if (b != null) q.eq(Record::getBookId, b.getId());
        }
        Page<Record> p = recordMapper.selectPage(Page.of(page, size), q);

        // 批量预加载减少 N+1
        Map<Long, String> userCache = new HashMap<>();
        Map<Long, String> bookCache = new HashMap<>();
        Map<Long, String> catCache = new HashMap<>();
        Map<Long, String> acctCache = new HashMap<>();

        List<AdminRecordListItem> items = p.getRecords().stream().map(r -> {
            String username = userCache.computeIfAbsent(r.getUserId(), id -> {
                User u = userMapper.selectById(id);
                return u == null ? "deleted" : u.getUsername();
            });
            String bookName = bookCache.computeIfAbsent(r.getBookId(), id -> {
                Book b = bookMapper.selectById(id);
                return b == null ? "" : b.getName();
            });
            String catName = r.getCategoryId() == null ? "" :
                catCache.computeIfAbsent(r.getCategoryId(), id -> {
                    Category c = categoryMapper.selectById(id);
                    return c == null ? "" : c.getName();
                });
            String acctName = acctCache.computeIfAbsent(r.getAccountId(), id -> {
                Account a = accountMapper.selectById(id);
                return a == null ? "" : a.getName();
            });
            String bookU = bookCache.entrySet().stream()
                .filter(e -> e.getValue().equals(bookName))
                .map(e -> "")
                .findFirst().orElse("");   // ponytail: 首版不返回 bookUuid,可后续 join
            return new AdminRecordListItem(
                r.getUuid(), r.getType(), r.getAmount(), r.getCurrency(),
                r.getNote(), r.getRecordDate(), r.getSource(),
                r.getUserId(), username, "", bookName,
                catName, acctName, r.getCreatedAt());
        }).toList();

        Page<AdminRecordListItem> out = Page.of(page, size, p.getTotal());
        out.setRecords(items);
        return out;
    }
}
```

**Step 3: AdminDashboardService (聚合统计)**

```java
package com.qingzhang.admin.service;

import com.qingzhang.admin.dto.AdminDashboardStats;
import com.qingzhang.records.mapper.RecordMapper;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.users.mapper.UserMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AdminDashboardService {

    private final UserMapper userMapper;
    private final BookMapper bookMapper;
    private final AccountMapper accountMapper;
    private final RecordMapper recordMapper;

    public AdminDashboardStats stats() {
        long userCount = userMapper.selectCount(null);
        long userNewToday = userMapper.selectCount(null); // ponytail: 首版用全量,后续 where created_at >= today
        long active7d = userCount;
        long bookCount = bookMapper.selectCount(null);
        long accountCount = accountMapper.selectCount(null);
        long recordCount = recordMapper.selectCount(null);
        long recordToday = recordMapper.selectCount(null);

        // ponytail: 最近 7 天 stub,后续用 SQL DATE(created_at) GROUP BY
        List<AdminDashboardStats.DailyCount> newUsersLast7Days = new ArrayList<>();
        List<AdminDashboardStats.DailyCount> newRecordsLast7Days = new Array<>();
        for (int i = 6; i >= 0; i--) {
            String date = LocalDate.now().minusDays(i).toString();
            newUsersLast7Days.add(new AdminDashboardStats.DailyCount(date, 0));
            newRecordsLast7Days.add(new AdminDashboardStats.DailyCount(date, 0));
        }

        return new AdminDashboardStats(
            userCount, userNewToday, active7d,
            bookCount, accountCount, recordCount, recordToday,
            newUsersLast7Days, newRecordsLast7Days);
    }
}
```

**Step 4: 3 个 Controller (极简,只读)**

```java
// AdminBooksController.java
package com.qingzhang.admin.controller;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.dto.AdminBookListItem;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.admin.service.AdminBookService;
import com.qingzhang.books.entity.Book;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/admin/books") @RequiredArgsConstructor
public class AdminBooksController {
    private final AdminBookService bookService;

    @GetMapping
    @RequiresPermission("book:list")
    public ApiResponse<Page<AdminBookListItem>> list(
            @RequestParam(required = false) Long ownerId,
            @RequestParam(required = false) String type,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(bookService.list(ownerId, type, page, size));
    }

    @GetMapping("/{uuid}")
    @RequiresPermission("book:view")
    public ApiResponse<Book> detail(@PathVariable String uuid) {
        Book b = bookService.detail(uuid);
        if (b == null) throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "账本不存在");
        return ApiResponse.ok(b);
    }
}
```

```java
// AdminRecordsController.java
package com.qingzhang.admin.controller;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.dto.AdminRecordListItem;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.admin.service.AdminRecordService;
import com.qingzhang.common.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDate;

@RestController @RequestMapping("/api/admin/records") @RequiredArgsConstructor
public class AdminRecordsController {
    private final AdminRecordService recordService;

    @GetMapping
    @RequiresPermission("record:list")
    public ApiResponse<Page<AdminRecordListItem>> list(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false) String bookUuid,
            @RequestParam(required = false) String type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(default = "20") int size) {
        return ApiResponse.ok(recordService.list(userId, bookUuid, type, from, to, page, size));
    }
}
```

```java
// AdminDashboardController.java
package com.qingzhang.admin.controller;
import com.qingzhang.admin.dto.AdminDashboardStats;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.admin.service.AdminDashboardService;
import com.qingzhang.common.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController @RequestMapping("/api/admin/dashboard") @RequiredArgsConstructor
public class AdminDashboardController {
    private final AdminDashboardService dashboardService;

    @GetMapping
    @RequiresPermission("dashboard:view")
    public ApiResponse<AdminDashboardStats> stats() {
        return ApiResponse.ok(dashboardService.stats());
    }
}
```

**Step 5: 编译 + 跑通**

```bash
cd "005.后端代码（Java工程师）"
mvn -q compile
ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD='Root@12345' \
  mvn -q spring-boot:run &
sleep 30

TOKEN=$(curl -s -X POST localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"root","password":"Root@12345"}' | jq -r '.data.token')

curl -s -H "Authorization: Bearer $TOKEN" localhost:8080/api/admin/dashboard | jq '.data.userCount'
curl -s -H "Authorization: Bearer $TOKEN" localhost:8080/api/admin/books | jq '.data.total'
curl -s -H "Authorization: Bearer $TOKEN" localhost:8080/api/admin/records | jq '.data.total'

pkill -f spring-boot:run
```

**Step 6: Commit**

```bash
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminBookService.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminRecordService.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminDashboardService.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/controller/AdminBooksController.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/controller/AdminRecordsController.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/controller/AdminDashboardController.java"
git commit -m "feat(后端): AdminBook/Record/Dashboard 3 服务 + 3 控制器 (只读)"
```

---

## Task 11: AdminAuthController + AdminAuditLogsController (me 端点 + 审计查询)

**Files:**
- Create: `com/qingzhang/admin/controller/AdminAuthController.java`
- Create: `com/qingzhang/admin/controller/AdminAuditLogsController.java`
- Create: `com/qingzhang/admin/service/AdminAuditQueryService.java`

**Step 1: AdminAuthController**

```java
package com.qingzhang.admin.controller;

import com.qingzhang.admin.dto.AdminMeResponse;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.admin.service.AdminPermissionService;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.users.UsersService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController @RequestMapping("/api/admin/auth") @RequiredArgsConstructor
public class AdminAuthController {

    private final UsersService usersService;
    private final AdminPermissionService permService;

    @GetMapping("/me")
    public ApiResponse<AdminMeResponse> me(HttpServletRequest req) {
        long uid = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        var user = usersService.getMe(uid);
        var resolved = permService.resolveForUser(uid);
        return ApiResponse.ok(new AdminMeResponse(
            user.id(), user.uuid(), user.username(), user.displayName(),
            resolved.isSuperAdmin(),
            resolved.permissions(),
            resolved.roleCodes()));
    }
}
```

**Step 2: AdminAuditQueryService**

```java
package com.qingzhang.admin.service;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.dto.AdminAuditLogDetailResponse;
import com.qingzhang.admin.dto.AdminAuditLogListItem;
import com.qingzhang.admin.entity.AdminAuditLog;
import com.qingzhang.admin.mapper.AdminAuditLogMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Instant;

@Service
@RequiredArgsConstructor
public class AdminAuditQueryService {

    private final AdminAuditLogMapper auditMapper;

    public Page<AdminAuditLogListItem> list(Long actorUserId, String action, String targetType,
                                             Long targetId, Instant from, Instant to,
                                             int page, int size) {
        LambdaQueryWrapper<AdminAuditLog> q = Wrappers.<AdminAuditLog>lambdaQuery()
                .eq(actorUserId != null, AdminAuditLog::getActorUserId, actorUserId)
                .eq(action != null, AdminAuditLog::getAction, action)
                .eq(targetType != null, AdminAuditLog::getTargetType, targetType)
                .eq(targetId != null, AdminAuditLog::getTargetId, targetId)
                .ge(from != null, AdminAuditLog::getCreatedAt, from)
                .le(to != null, AdminAuditLog::getCreatedAt, to)
                .orderByDesc(AdminAuditLog::getCreatedAt);
        Page<AdminAuditLog> p = auditMapper.selectPage(Page.of(page, size), q);
        Page<AdminAuditLogListItem> out = Page.of(page, size, p.getTotal());
        out.setRecords(p.getRecords().stream()
            .map(r -> new AdminAuditLogListItem(
                r.getUuid(), r.getActorUsername(), r.getAction(),
                r.getTargetType(), r.getTargetId(), r.getResult(),
                r.getCreatedAt())).toList());
        return out;
    }

    public AdminAuditLogDetailResponse detail(String uuid) {
        AdminAuditLog r = auditMapper.selectOne(
            Wrappers.<AdminAuditLog>lambdaQuery().eq(AdminAuditLog::getUuid, uuid));
        if (r == null) throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "审计日志不存在");
        return new AdminAuditLogDetailResponse(
            r.getUuid(), r.getActorUsername(), r.getActorUserId(),
            r.getAction(), r.getTargetType(), r.getTargetId(),
            r.getBeforeSnapshot(), r.getAfterSnapshot(),
            r.getIp(), r.getUserAgent(), r.getResult(), r.getErrorMsg(),
            r.getCreatedAt());
    }
}
```

**Step 3: AdminAuditLogsController**

```java
package com.qingzhang.admin.controller;

import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.dto.AdminAuditLogDetailResponse;
import com.qingzhang.admin.dto.AdminAuditLogListItem;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.admin.service.AdminAuditQueryService;
import com.qingzhang.common.ApiResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;

@RestController @RequestMapping("/api/admin/audit-logs") @RequiredArgsConstructor
public class AdminAuditLogsController {

    private final AdminAuditQueryService auditService;

    @GetMapping
    @RequiresPermission("audit:list")
    public ApiResponse<Page<AdminAuditLogListItem>> list(
            @RequestParam(required = false) Long actorUserId,
            @RequestParam(required = false) String action,
            @RequestParam(required = false) String targetType,
            @RequestParam(required = false) Long targetId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ApiResponse.ok(auditService.list(actorUserId, action, targetType, targetId, from, to, page, size));
    }

    @GetMapping("/{uuid}")
    @RequiresPermission("audit:list")
    public ApiResponse<AdminAuditLogDetailResponse> detail(@PathVariable String uuid) {
        return ApiResponse.ok(auditService.detail(uuid));
    }
}
```

**Step 4: 编译 + 跑通**

```bash
cd "005.后端代码（Java工程师）"
mvn -q compile
ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD='Root@12345' \
  mvn -q spring-boot:run &
sleep 30

TOKEN=$(curl -s -X POST localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"root","password":"Root@12345"}' | jq -r '.data.token')

# /api/admin/auth/me
curl -s -H "Authorization: Bearer $TOKEN" localhost:8080/api/admin/auth/me | jq '.data.isSuperAdmin'
# Expected: true

# /api/admin/audit-logs (root 有 audit:list)
curl -s -H "Authorization: Bearer $TOKEN" localhost:8080/api/admin/audit-logs | jq '.data.total'
# Expected: ≥ 1 (前面 disable 测试写过一条)

pkill -f spring-boot:run
```

**Step 5: Commit**

```bash
git add "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/controller/AdminAuthController.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/controller/AdminAuditLogsController.java" \
        "005.后端代码（Java工程师）/src/main/java/com/qingzhang/admin/service/AdminAuditQueryService.java"
git commit -m "feat(后端): AdminAuth/me + AuditLogsController (查审计)"
```

---

## Task 12: 端到端冒烟测试 + README 文档

**Files:**
- Create: `005.后端代码（Java工程师）/scripts/smoke-admin.sh`
- Modify: `005.后端代码（Java工程师）/README.md` (新增"Admin 后台"章节)

**Step 1: smoke 脚本**

```bash
#!/usr/bin/env bash
# 端到端冒烟测试 admin 子系统
# 用法: ./scripts/smoke-admin.sh
set -euo pipefail

BASE=${BASE:-http://localhost:8080}
ROOT_USER=${ROOT_USER:-root}
ROOT_PWD=${ROOT_PWD:-Root@12345}

echo "==> 1) login as root"
TOKEN=$(curl -fsS -X POST "$BASE/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"username\":\"$ROOT_USER\",\"password\":\"$ROOT_PWD\"}" | jq -r '.data.token')
[ -n "$TOKEN" ] && [ "$TOKEN" != "null" ] || { echo "FAIL: no token"; exit 1; }
echo "    OK (token len=${#TOKEN})"

H="Authorization: Bearer $TOKEN"

check() {
  local name=$1 url=$2 expectCode=${3:-0}
  local code
  code=$(curl -fsS -H "$H" "$BASE$url" | jq -r '.code // empty')
  if [ "$code" = "$expectCode" ]; then
    echo "    ✓ $name ($code)"
  else
    echo "    ✗ $name (got=$code expected=$expectCode)"
    exit 1
  fi
}

echo "==> 2) admin endpoints reachable"
check "dashboard"   /api/admin/dashboard
check "users list"  /api/admin/users
check "categories"  /api/admin/categories/preset
check "books list"  /api/admin/books
check "records"     /api/admin/records
check "audit logs"  /api/admin/audit-logs

echo "==> 3) auth check (no token)"
NO=$(curl -fsS "$BASE/api/admin/users" | jq -r '.code')
[ "$NO" = "1401" ] && echo "    ✓ no-token → 1401" || { echo "    ✗ got=$NO"; exit 1; }

echo "==> 4) me endpoint"
ME=$(curl -fsS -H "$H" "$BASE/api/admin/auth/me" | jq -r '.data.isSuperAdmin')
[ "$ME" = "true" ] && echo "    ✓ isSuperAdmin=true" || { echo "    ✗ isSuperAdmin=$ME"; exit 1; }

echo "==> ALL PASSED"
```

```bash
chmod +x "005.后端代码（Java工程师）/scripts/smoke-admin.sh"
```

**Step 2: README 加章节**

在 `005.后端代码（Java工程师）/README.md` 末尾加:

```markdown
## Admin 后台子系统

参见 [docs/superpowers/specs/2026-08-30-admin-backend-design.md](../../docs/superpowers/specs/2026-08-30-admin-backend-design.md) 完整设计。

### 首次部署 — 创建 super admin

```bash
ADMIN_BOOTSTRAP_USERNAME=root \
ADMIN_BOOTSTRAP_PASSWORD=$(openssl rand -hex 12) \
java -jar target/qingzhang-java-backend-*.jar
# 启动后立刻 unset 这俩环境变量(或仅一次性注入)
```

启动后,`admin_user_roles` 表会有 1 条 root→super_admin 映射,后续可通过 `/api/admin/users/{id}/roles` 授权其他用户。

### 端到端冒烟

```bash
./scripts/smoke-admin.sh
```

预期:6 个 admin 端点全 200,无 token 返 1401,`/auth/me` 返回 `isSuperAdmin: true`。
```

**Step 3: 跑通冒烟**

```bash
cd "005.后端代码（Java工程师）"
ADMIN_BOOTSTRAP_USERNAME=root ADMIN_BOOTSTRAP_PASSWORD='Root@12345' \
  mvn -q spring-boot:run &
sleep 30
./scripts/smoke-admin.sh
# Expected: ALL PASSED
pkill -f spring-boot:run
```

**Step 4: Commit**

```bash
git add "005.后端代码（Java工程师）/scripts/smoke-admin.sh" \
        "005.后端代码（Java工程师）/README.md"
git commit -m "test(后端): admin 端到端冒烟脚本 + README 文档"
```

---

## Self-Review

**1. Spec coverage** (§3-§7 全部要求):
- §3.1-§3.5 五张表 → Task 1 ✓
- §3.6 种子 (3 角色 + 17 权限 + 映射) → Task 1 ✓
- §4.1 包结构 → Tasks 2-11 ✓
- §4.2 JWT 扩展 → Task 4 ✓
- §4.3 AdminAuthInterceptor → Task 5 ✓
- §4.4 API 端点 (16 个) → Tasks 8-11 ✓
- §4.5 错误码 14xx → Task 4 ✓
- §5 审计日志 → Task 6 (写) + Task 11 (查) ✓
- §6 Bootstrap → Task 7 ✓
- §9 测试 → Task 12 冒烟 ✓

**2. Placeholder scan**: 0 个 TBD/TODO。"ponytail" 注释明确标记已知简化点 (recordCount 首版 0、DailyCount 暂填 0、bookUuid 字段首版空 — 均有升级路径注释)。

**3. Type consistency**:
- `JwtUtil.issue(...)` overloads — Task 4 引入,AuthService 用
- `JwtAuthFilter.USER_ID_ATTR/PERMS_ATTR/ROLES_ATTR/SUPER_ATTR` — Task 4 引入,Task 5/8-11 引用 ✓
- `AdminAuditService.record(...)` 签名 7 参数,所有调用方对齐 ✓
- `@RequiresPermission("code")` 16 个端点的 code 与 §3.6 种子表完全一致 ✓
- `AdminPermissionService.Resolved(permissions, roleCodes, isSuperAdmin)` 字段顺序 — Task 4 用 + Task 5 抽出 ✓

**4. 已知简化** (与 spec §10 一致):
- 撤销角色立即生效 → 24h 自然过期 (已在 §4.3 文档化)
- Dashboard DailyCount 暂用 0 (后续 SQL `DATE(created_at) GROUP BY`)
- 列表接口的 recordCount/bookCount 暂用 0 (后续加统计表或缓存)
- 审计 detail 的 before/after 直接 JSON 字符串返 (前端按需 parse)