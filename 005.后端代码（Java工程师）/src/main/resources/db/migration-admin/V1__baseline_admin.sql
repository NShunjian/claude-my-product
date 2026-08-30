-- =============================================================================
-- Admin DB V1 baseline —— 6 张管理后台表 + 种子数据
--
-- 与 docs/superpowers/specs/2026-08-30-admin-backend-design.md §3 + V5/V6 对齐。
-- 这里直接以 V6 之后的最终形态建表(列名 admin_user_id/actor_admin_user_id,
-- FK fk_aur_admin_user),不再走 V5→V6 渐进迁移 —— 因为本 schema 物理隔离后
-- 没有历史包袱。
--
-- 对应 user DB 的 V7__drop_admin_tables.sql 把同 6 张表从 user DB 删掉,
-- user DB 只剩业务表(users/books/records/categories 等)。
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 1. admin_users —— 后台账号(id 自 1000 起,与 users.id 数值区间分开)
-- -----------------------------------------------------------------------------
CREATE TABLE `admin_users` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `username`            VARCHAR(50)      NOT NULL                                COMMENT '登录用户名,独立于 users.username',
  `password_hash`       VARCHAR(128)     NOT NULL                                COMMENT 'BCrypt 哈希',
  `display_name`        VARCHAR(50)      DEFAULT NULL,
  `status`              TINYINT          NOT NULL DEFAULT 1                      COMMENT '1=启用 0=禁用',
  `last_login_at`       DATETIME(3)      DEFAULT NULL,
  `last_login_ip`       VARCHAR(64)      DEFAULT NULL,
  `mfa_secret`          VARCHAR(64)      DEFAULT NULL                            COMMENT 'V1.1 预留:TOTP secret',
  `password_expires_at` DATETIME(3)      DEFAULT NULL                            COMMENT 'V1.1 预留:密码过期时间',
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`          DATETIME(3)      DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_users_uuid`     (`uuid`),
  UNIQUE KEY `uk_admin_users_username` (`username`),
  KEY `idx_admin_users_created_at`    (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  AUTO_INCREMENT = 1000
  COMMENT='后台管理员账号';

-- -----------------------------------------------------------------------------
-- 2. admin_roles
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 3. admin_permissions
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- 4. admin_role_permissions —— 角色-权限映射
-- -----------------------------------------------------------------------------
CREATE TABLE `admin_role_permissions` (
  `role_id`       BIGINT UNSIGNED NOT NULL,
  `permission_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`role_id`, `permission_id`),
  CONSTRAINT `fk_arp_role`       FOREIGN KEY (`role_id`)       REFERENCES `admin_roles` (`id`)       ON DELETE CASCADE,
  CONSTRAINT `fk_arp_permission` FOREIGN KEY (`permission_id`) REFERENCES `admin_permissions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='角色-权限映射';

-- -----------------------------------------------------------------------------
-- 5. admin_user_roles —— 用户-角色授权
--    列名 admin_user_id(FK 到 admin_users.id),不再到 users.id
-- -----------------------------------------------------------------------------
CREATE TABLE `admin_user_roles` (
  `admin_user_id` BIGINT UNSIGNED NOT NULL,
  `role_id`       BIGINT UNSIGNED NOT NULL,
  `granted_at`    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `granted_by`    BIGINT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`admin_user_id`, `role_id`),
  KEY `idx_aur_admin_user` (`admin_user_id`),
  CONSTRAINT `fk_aur_admin_user` FOREIGN KEY (`admin_user_id`) REFERENCES `admin_users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_aur_role`       FOREIGN KEY (`role_id`)       REFERENCES `admin_roles` (`id`)   ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户-角色授权';

-- -----------------------------------------------------------------------------
-- 6. admin_audit_logs —— 操作审计
--    列名 actor_admin_user_id,引用 admin_users.id(无 FK,允许 user_id=NULL 表示系统操作)
-- -----------------------------------------------------------------------------
CREATE TABLE `admin_audit_logs` (
  `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `uuid`                 CHAR(36)        NOT NULL,
  `actor_admin_user_id`  BIGINT UNSIGNED DEFAULT NULL,
  `actor_username`       VARCHAR(50)     NOT NULL DEFAULT '',
  `action`               VARCHAR(64)     NOT NULL,
  `target_type`          VARCHAR(32)     DEFAULT NULL,
  `target_id`            BIGINT UNSIGNED DEFAULT NULL,
  `before_snapshot`      JSON            DEFAULT NULL,
  `after_snapshot`       JSON            DEFAULT NULL,
  `ip`                   VARCHAR(64)     DEFAULT NULL,
  `user_agent`           VARCHAR(255)    DEFAULT NULL,
  `result`               ENUM('success','failure') NOT NULL DEFAULT 'success',
  `error_msg`            VARCHAR(500)    DEFAULT NULL,
  `created_at`           DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_audit_logs_uuid` (`uuid`),
  KEY `idx_audit_logs_actor_admin_created` (`actor_admin_user_id`, `created_at`),
  KEY `idx_audit_logs_target`              (`target_type`, `target_id`),
  KEY `idx_audit_logs_action`              (`action`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台操作审计';

-- -----------------------------------------------------------------------------
-- Seed: 3 角色 + 权限码 + 角色-权限映射
-- -----------------------------------------------------------------------------
INSERT INTO `admin_roles` (`uuid`, `code`, `name`, `description`, `status`) VALUES
  (UUID(), 'super_admin', '超级管理员', '全部权限', 1),
  (UUID(), 'admin',       '管理员',     '除角色管理与审计外的全部权限', 1),
  (UUID(), 'viewer',      '只读审计员', '仅读权限', 1);

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
