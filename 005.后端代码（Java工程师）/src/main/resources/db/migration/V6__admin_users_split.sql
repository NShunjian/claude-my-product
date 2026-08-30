-- =============================================================================
-- V6: 把 admin 账号从 users 表拆到独立 admin_users 表
--
-- 背景:
--   - 之前 admin_users 不存在,admin 账号共享 users 表(id=105 是现有 super_admin)
--   - users.username 是登录入口,admin 跟普通用户抢同一张表,字段需求也不同
--     (admin 需 MFA / last_login_ip / password_expires_at 等,普通用户不需要)
--   - admin 账号迁移后,users.username 与 admin_users.username 不再互引,
--     两表各自独立 UNIQUE
--
-- 不做(留给后续):
--   - 不删 users.username UNIQUE 索引(普通用户仍依赖)
--   - 不引入 admin_<x> 前缀(username 是业务标识,改前缀有兼容代价)
--   - 不回填 mfa_secret / password_expires_at(字段预留,V1.1 UI 接)
--
-- 安全:
--   - 全程 FOREIGN_KEY_CHECKS=0,确保多步 rename/repoint 不被 MySQL 拒
--   - 不动 books/book_members/records 等业务表,假设 admin 账号从未拥有账本
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 1. 新建 admin_users 表
-- -----------------------------------------------------------------------------
-- 字段对齐 users(id/uuid/username/password_hash/display_name/status/
--   last_login_at/last_login_ip/created_at/updated_at),另加 admin 专属预留字段
-- AUTO_INCREMENT 起始 1000,避免与现有 users.id(=105) 数值相近时误判来源
-- -----------------------------------------------------------------------------
CREATE TABLE `admin_users` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `username`            VARCHAR(50)      NOT NULL                                COMMENT '登录用户名,独立于 users.username,仅 admin 登录用',
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='后台管理员账号';

-- -----------------------------------------------------------------------------
-- 2. 数据迁移:把现有 admin 账号从 users 拷到 admin_users
--    选取标准:出现在 admin_user_roles.user_id 中的任意用户 = admin
--    假设当前只有 id=105 这一个 admin (env 引导出来的 super_admin)
-- -----------------------------------------------------------------------------
INSERT INTO `admin_users`
  (`uuid`, `username`, `password_hash`, `display_name`, `status`,
   `last_login_at`, `last_login_ip`, `created_at`, `updated_at`)
SELECT u.`uuid`, u.`username`, u.`password_hash`, u.`display_name`, u.`status`,
       u.`last_login_at`, u.`last_login_ip`, u.`created_at`, u.`updated_at`
  FROM `users` u
 WHERE u.`id` IN (SELECT DISTINCT `user_id` FROM `admin_user_roles`);

-- -----------------------------------------------------------------------------
-- 3. 重映射 admin_user_roles.user_id -> 新 admin_users.id
--    通过 username 桥接(两表 username 唯一)
-- -----------------------------------------------------------------------------
UPDATE `admin_user_roles` aur
  JOIN `users` u ON aur.`user_id` = u.`id`
  JOIN `admin_users` au ON au.`username` = u.`username`
   SET aur.`user_id` = au.`id`;

-- -----------------------------------------------------------------------------
-- 4. 重映射 admin_audit_logs.actor_user_id -> 新 admin_users.id
--    actor_user_id 没 FK 约束(只是普通列),重命名见 step 6
-- -----------------------------------------------------------------------------
UPDATE `admin_audit_logs` aal
  JOIN `users` u ON aal.`actor_user_id` = u.`id`
  JOIN `admin_users` au ON au.`username` = u.`username`
   SET aal.`actor_user_id` = au.`id`
 WHERE aal.`actor_user_id` IS NOT NULL
   AND u.`id` IN (SELECT DISTINCT `user_id` FROM `admin_user_roles`);

-- -----------------------------------------------------------------------------
-- 5. 拆 FK:admin_user_roles.user_id 原本 -> users.id
--    必须先 drop,否则 step 6 重命名列会被 FK 阻止
-- -----------------------------------------------------------------------------
ALTER TABLE `admin_user_roles` DROP FOREIGN KEY `fk_aur_user`;

-- -----------------------------------------------------------------------------
-- 6. 列改名:user_id -> admin_user_id,actor_user_id -> actor_admin_user_id
--    同步索引名,避免遗留 user_id 字样误导
-- -----------------------------------------------------------------------------
ALTER TABLE `admin_user_roles`
  CHANGE COLUMN `user_id` `admin_user_id` BIGINT UNSIGNED NOT NULL;

ALTER TABLE `admin_user_roles`
  RENAME INDEX `idx_aur_user` TO `idx_aur_admin_user`;

ALTER TABLE `admin_audit_logs`
  CHANGE COLUMN `actor_user_id` `actor_admin_user_id` BIGINT UNSIGNED DEFAULT NULL;

ALTER TABLE `admin_audit_logs`
  RENAME INDEX `idx_audit_logs_actor_created` TO `idx_audit_logs_actor_admin_created`;

-- -----------------------------------------------------------------------------
-- 7. 重建 FK:admin_user_roles.admin_user_id -> admin_users.id
--    ON DELETE CASCADE 与原约束保持一致
-- -----------------------------------------------------------------------------
ALTER TABLE `admin_user_roles`
  ADD CONSTRAINT `fk_aur_admin_user`
      FOREIGN KEY (`admin_user_id`) REFERENCES `admin_users` (`id`)
      ON DELETE CASCADE;

-- -----------------------------------------------------------------------------
-- 8. 删除已迁移的旧 admin 行(users)
--    此时 admin_user_roles 已不再 FK users,所以可安全删除
--    books.owner_id / records.user_id 等若有引用会 RESTRICT 阻止 —— 此时应
--    不存在,因 AdminBootstrapService 不建账本/账目
-- -----------------------------------------------------------------------------
DELETE FROM `users`
 WHERE `username` IN (SELECT `username` FROM `admin_users`);

-- -----------------------------------------------------------------------------
-- 9. admin_users.AUTO_INCREMENT 起始 1000,与 users.id 数值区间分开
-- -----------------------------------------------------------------------------
ALTER TABLE `admin_users` AUTO_INCREMENT = 1000;

SET FOREIGN_KEY_CHECKS = 1;