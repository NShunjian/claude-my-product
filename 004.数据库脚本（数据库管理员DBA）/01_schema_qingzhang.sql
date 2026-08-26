-- =============================================================================
-- 轻账 (QingZhang) 数据库表结构脚本
-- -----------------------------------------------------------------------------
-- 适用数据库：MySQL 8.0+ （推荐 utf8mb4 字符集）
-- 同步参考：
--   · 001.产品PRD/轻账-产品需求文档PRD.md          （V1.0 基线）
--   · 001.产品PRD/轻账-产品需求文档PRD-V1.0.1.md    （V1.0.1 用户认证增量）
--   · 003.前端代码/frontend/qingzhang/src/types     （前端 TypeScript 类型）
--   · 003.前端代码/frontend/qingzhang/src/db        （Dexie v2 索引定义）
-- 设计原则：
--   1. 字段命名同时兼顾业务可读性（snake_case）与前端 UUID 对齐（uuid 列）
--   2. 所有业务表保留软删除字段（V1.1 云同步/审计需要）
--   3. 金额统一使用 DECIMAL(12,2)，避免浮点误差
--   4. 时间统一使用 DATETIME(3) 毫秒精度，匹配前端 createdAt/updatedAt
--   5. 预留 V1.1 / V2.0 字段（共享账本 / 预算 / 多币种），不破坏 V1.0 兼容
-- =============================================================================

-- 设置字符集与 SQL 模式
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

-- 建议先创建独立数据库
-- CREATE DATABASE IF NOT EXISTS `qingzhang` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
-- USE `qingzhang`;

-- -----------------------------------------------------------------------------
-- 1. users —— 用户表
-- -----------------------------------------------------------------------------
-- 对齐 PRD V1.0.1 §5.2
-- 前端 TypeScript：src/types/index.ts → User
-- Dexie 表：users (id, username)
DROP TABLE IF EXISTS `users`;
CREATE TABLE `users` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT             COMMENT '物理主键',
  `uuid`                CHAR(36)         NOT NULL                            COMMENT '业务主键 UUID（与前端 ID 对齐）',
  `username`            VARCHAR(20)      NOT NULL                            COMMENT '登录用户名，唯一',
  `password_hash`       VARCHAR(128)     NOT NULL                            COMMENT '密码哈希值（SHA-256 + salt）',
  `salt`                VARCHAR(64)      NOT NULL                            COMMENT '随机盐（16 字节 base64）',
  `display_name`        VARCHAR(50)      DEFAULT NULL                        COMMENT '昵称',
  `avatar`              VARCHAR(255)     DEFAULT NULL                        COMMENT '头像 URL',
  `email`               VARCHAR(100)     DEFAULT NULL                        COMMENT '邮箱（V1.1 预留）',
  `phone`               VARCHAR(20)      DEFAULT NULL                        COMMENT '手机号（V1.1 预留）',
  `status`              TINYINT          NOT NULL DEFAULT 1                  COMMENT '状态：1=启用 0=禁用',
  `last_login_at`       DATETIME(3)      DEFAULT NULL                        COMMENT '最近登录时间',
  `last_login_ip`       VARCHAR(64)      DEFAULT NULL                        COMMENT '最近登录 IP',
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '注册时间',
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '更新时间',
  `deleted_at`          DATETIME(3)      DEFAULT NULL                        COMMENT '软删除时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_uuid`     (`uuid`),
  UNIQUE KEY `uk_users_username` (`username`),
  KEY `idx_users_created_at`    (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- -----------------------------------------------------------------------------
-- 2. books —— 账本表
-- -----------------------------------------------------------------------------
-- 对齐 PRD V1.0 §6.1 / V1.1 共享账本
-- V1.0.1：每用户默认 1 个「个人账本」，数据全局共享；结构已为 V1.1 共享账本预留
DROP TABLE IF EXISTS `books`;
CREATE TABLE `books` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT             COMMENT '物理主键',
  `uuid`                CHAR(36)         NOT NULL                            COMMENT '业务主键 UUID',
  `owner_id`            BIGINT UNSIGNED  NOT NULL                            COMMENT '账本所有者（→ users.id）',
  `name`                VARCHAR(50)      NOT NULL                            COMMENT '账本名称',
  `description`         VARCHAR(255)     DEFAULT NULL                        COMMENT '账本描述',
  `type`                ENUM('personal','shared','business') NOT NULL DEFAULT 'personal' COMMENT '账本类型',
  `currency`            CHAR(3)          NOT NULL DEFAULT 'CNY'              COMMENT '默认币种（V2.0 多币种预留）',
  `is_default`          TINYINT          NOT NULL DEFAULT 0                  COMMENT '是否用户默认账本',
  `is_archived`         TINYINT          NOT NULL DEFAULT 0                  COMMENT '是否归档',
  `sort_order`          INT              NOT NULL DEFAULT 0                  COMMENT '排序权重',
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`          DATETIME(3)      DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_books_uuid` (`uuid`),
  KEY `idx_books_owner`        (`owner_id`, `is_archived`),
  KEY `idx_books_default`      (`owner_id`, `is_default`),
  CONSTRAINT `fk_books_owner`   FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账本表';

-- -----------------------------------------------------------------------------
-- 3. book_members —— 账本成员表（V1.1 共享账本预留）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `book_members`;
CREATE TABLE `book_members` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `book_id`             BIGINT UNSIGNED  NOT NULL                            COMMENT '→ books.id',
  `user_id`             BIGINT UNSIGNED  NOT NULL                            COMMENT '→ users.id',
  `role`                ENUM('owner','admin','editor','viewer') NOT NULL DEFAULT 'editor' COMMENT '成员角色',
  `joined_at`           DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `invited_by`          BIGINT UNSIGNED  DEFAULT NULL                        COMMENT '邀请人 user_id',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_book_member` (`book_id`, `user_id`),
  KEY `idx_book_members_user` (`user_id`),
  CONSTRAINT `fk_book_members_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_book_members_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账本成员（V1.1）';

-- -----------------------------------------------------------------------------
-- 4. categories —— 分类表
-- -----------------------------------------------------------------------------
-- 对齐 PRD V1.0 §4.1 默认分类 + §6.2 categories
-- V1.0 分类不可自定义；V1.1 起允许用户自定义（user_id IS NOT NULL）
-- 前端：src/constants/categories.ts
DROP TABLE IF EXISTS `categories`;
CREATE TABLE `categories` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL                            COMMENT '业务主键 UUID（前端使用）',
  `user_id`             BIGINT UNSIGNED  DEFAULT NULL                        COMMENT '所属用户：NULL 表示系统预设',
  `book_id`             BIGINT UNSIGNED  DEFAULT NULL                        COMMENT '所属账本：NULL 表示跨账本预设',
  `type`                ENUM('expense','income') NOT NULL                   COMMENT '类型：支出/收入',
  `name`                VARCHAR(10)      NOT NULL                            COMMENT '分类名称',
  `icon`                VARCHAR(32)      NOT NULL DEFAULT ''                 COMMENT '图标（emoji 或标识）',
  `color`               VARCHAR(16)      NOT NULL DEFAULT '#A0AEC0'          COMMENT '颜色色值',
  `is_preset`           TINYINT          NOT NULL DEFAULT 0                  COMMENT '是否系统预设',
  `is_active`           TINYINT          NOT NULL DEFAULT 1                  COMMENT '是否启用',
  `sort_order`          INT              NOT NULL DEFAULT 0                  COMMENT '排序权重',
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`          DATETIME(3)      DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_categories_uuid` (`uuid`),
  KEY `idx_categories_user_type`  (`user_id`, `type`, `is_active`),
  KEY `idx_categories_book_type`  (`book_id`, `type`, `is_active`),
  KEY `idx_categories_preset`     (`is_preset`, `type`, `sort_order`),
  CONSTRAINT `fk_categories_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_categories_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分类表';

-- -----------------------------------------------------------------------------
-- 5. accounts —— 账户表
-- -----------------------------------------------------------------------------
-- 对齐 PRD V1.0 §4.1 账户管理 + §6.2 accounts
-- 前端：src/constants/accounts.ts（5 个预设）
DROP TABLE IF EXISTS `accounts`;
CREATE TABLE `accounts` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL                            COMMENT '业务主键 UUID',
  `user_id`             BIGINT UNSIGNED  NOT NULL                            COMMENT '所属用户',
  `book_id`             BIGINT UNSIGNED  DEFAULT NULL                        COMMENT '所属账本（NULL 表示全账本通用）',
  `name`                VARCHAR(20)      NOT NULL                            COMMENT '账户名称',
  `icon`                VARCHAR(32)      NOT NULL DEFAULT '💳'              COMMENT '图标',
  `type`                ENUM('cash','debit','credit','wallet','investment','other') NOT NULL DEFAULT 'wallet' COMMENT '账户类型',
  `initial_balance`     DECIMAL(14,2)    NOT NULL DEFAULT 0.00               COMMENT '初始余额',
  `current_balance`     DECIMAL(14,2)    NOT NULL DEFAULT 0.00               COMMENT '当前余额（缓存，按账目实时计算回填）',
  `currency`            CHAR(3)          NOT NULL DEFAULT 'CNY'              COMMENT '币种（V2.0 多币种）',
  `is_default`          TINYINT          NOT NULL DEFAULT 0                  COMMENT '是否默认账户',
  `is_archived`         TINYINT          NOT NULL DEFAULT 0                  COMMENT '是否归档',
  `sort_order`          INT              NOT NULL DEFAULT 0                  COMMENT '排序权重',
  `note`                VARCHAR(255)     DEFAULT NULL                        COMMENT '备注',
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`          DATETIME(3)      DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_accounts_uuid` (`uuid`),
  KEY `idx_accounts_user_default` (`user_id`, `is_default`, `is_archived`),
  KEY `idx_accounts_user_sort`   (`user_id`, `is_archived`, `sort_order`),
  KEY `idx_accounts_book`        (`book_id`),
  CONSTRAINT `fk_accounts_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_accounts_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账户表';

-- -----------------------------------------------------------------------------
-- 6. records —— 账目记录表（核心流水）
-- -----------------------------------------------------------------------------
-- 对齐 PRD V1.0 §4.2 快速记账 + §6.2 records
-- 前端：src/types/index.ts → Record
-- Dexie 索引：id, type, categoryId, accountId, recordDate, createdAt
DROP TABLE IF EXISTS `records`;
CREATE TABLE `records` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL                            COMMENT '业务主键 UUID',
  `user_id`             BIGINT UNSIGNED  NOT NULL                            COMMENT '记账用户',
  `book_id`             BIGINT UNSIGNED  NOT NULL                            COMMENT '所属账本',
  `type`                ENUM('expense','income','transfer') NOT NULL        COMMENT '类型',
  `category_id`         BIGINT UNSIGNED  DEFAULT NULL                        COMMENT '分类（转账时为 NULL）',
  `account_id`          BIGINT UNSIGNED  NOT NULL                            COMMENT '账户',
  `to_account_id`       BIGINT UNSIGNED  DEFAULT NULL                        COMMENT '转入账户（仅转账记录使用）',
  `amount`              DECIMAL(12,2)    NOT NULL                            COMMENT '金额（正数）',
  `currency`            CHAR(3)          NOT NULL DEFAULT 'CNY'              COMMENT '币种',
  `note`                VARCHAR(50)      DEFAULT NULL                        COMMENT '备注',
  `record_date`         DATE             NOT NULL                            COMMENT '记账日期',
  `source`              ENUM('manual','import','ocr','auto','sync') NOT NULL DEFAULT 'manual' COMMENT '数据来源',
  `location`            VARCHAR(255)     DEFAULT NULL                        COMMENT '地点（V1.1 预留）',
  `client_id`           VARCHAR(64)      DEFAULT NULL                        COMMENT '前端离线创建 ID（用于云同步去重）',
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`          DATETIME(3)      DEFAULT NULL                        COMMENT '软删除',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_records_uuid`    (`uuid`),
  UNIQUE KEY `uk_records_client`  (`user_id`, `client_id`),
  KEY `idx_records_user_date`     (`user_id`, `record_date`),
  KEY `idx_records_book_date`     (`book_id`, `record_date`),
  KEY `idx_records_account_date`  (`account_id`, `record_date`),
  KEY `idx_records_category_date` (`category_id`, `record_date`),
  KEY `idx_records_user_type_date`(`user_id`, `type`, `record_date`),
  KEY `idx_records_created`       (`user_id`, `created_at`),
  CONSTRAINT `fk_records_user`     FOREIGN KEY (`user_id`)     REFERENCES `users` (`id`)      ON DELETE CASCADE,
  CONSTRAINT `fk_records_book`     FOREIGN KEY (`book_id`)     REFERENCES `books` (`id`)      ON DELETE RESTRICT,
  CONSTRAINT `fk_records_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_records_account`  FOREIGN KEY (`account_id`)  REFERENCES `accounts` (`id`)   ON DELETE RESTRICT,
  CONSTRAINT `fk_records_to_acct`  FOREIGN KEY (`to_account_id`) REFERENCES `accounts` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `chk_records_amount`  CHECK (`amount` > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账目流水表';

-- -----------------------------------------------------------------------------
-- 7. record_attachments —— 账目附件表（V1.1 OCR 拍照记账预留）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `record_attachments`;
CREATE TABLE `record_attachments` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `record_id`           BIGINT UNSIGNED  NOT NULL                            COMMENT '→ records.id',
  `file_url`            VARCHAR(500)     NOT NULL                            COMMENT '附件 URL',
  `file_type`           ENUM('image','pdf','audio','other') NOT NULL DEFAULT 'image',
  `file_size`           INT UNSIGNED     DEFAULT NULL                        COMMENT '文件字节数',
  `ocr_raw`             JSON             DEFAULT NULL                        COMMENT 'OCR 原始识别结果',
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_record_attachments_uuid` (`uuid`),
  KEY `idx_record_attachments_record` (`record_id`),
  CONSTRAINT `fk_record_attachments_record` FOREIGN KEY (`record_id`) REFERENCES `records` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账目附件表';

-- -----------------------------------------------------------------------------
-- 8. budgets —— 预算表（V2.0 预留）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `budgets`;
CREATE TABLE `budgets` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `user_id`             BIGINT UNSIGNED  NOT NULL,
  `book_id`             BIGINT UNSIGNED  NOT NULL,
  `category_id`         BIGINT UNSIGNED  DEFAULT NULL                        COMMENT 'NULL 表示总预算',
  `amount`              DECIMAL(12,2)    NOT NULL,
  `period`              ENUM('monthly','yearly','weekly') NOT NULL DEFAULT 'monthly' COMMENT '周期',
  `start_date`          DATE             NOT NULL,
  `end_date`            DATE             DEFAULT NULL,
  `alert_threshold`     DECIMAL(5,2)     NOT NULL DEFAULT 0.80               COMMENT '预警阈值（百分比）',
  `is_active`           TINYINT          NOT NULL DEFAULT 1,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_budgets_uuid` (`uuid`),
  KEY `idx_budgets_user_period` (`user_id`, `period`, `is_active`),
  CONSTRAINT `fk_budgets_user`     FOREIGN KEY (`user_id`)     REFERENCES `users` (`id`)      ON DELETE CASCADE,
  CONSTRAINT `fk_budgets_book`     FOREIGN KEY (`book_id`)     REFERENCES `books` (`id`)      ON DELETE CASCADE,
  CONSTRAINT `fk_budgets_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='预算表（V2.0）';

-- -----------------------------------------------------------------------------
-- 9. export_logs —— 导出日志表
-- -----------------------------------------------------------------------------
-- 对齐 PRD V1.0 §4.2 Excel 导出
DROP TABLE IF EXISTS `export_logs`;
CREATE TABLE `export_logs` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `user_id`             BIGINT UNSIGNED  NOT NULL,
  `export_type`         ENUM('monthly','category','full','custom') NOT NULL    COMMENT '导出类型',
  `file_name`           VARCHAR(255)     NOT NULL                            COMMENT '导出文件名',
  `file_url`            VARCHAR(500)     DEFAULT NULL                        COMMENT '文件 URL',
  `file_size`           INT UNSIGNED     DEFAULT NULL,
  `record_count`        INT UNSIGNED     NOT NULL DEFAULT 0                  COMMENT '导出条数',
  `filter_json`         JSON             DEFAULT NULL                        COMMENT '过滤条件 JSON',
  `status`              ENUM('pending','success','failed') NOT NULL DEFAULT 'pending',
  `error_msg`           VARCHAR(500)     DEFAULT NULL,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_export_logs_uuid` (`uuid`),
  KEY `idx_export_logs_user_created` (`user_id`, `created_at`),
  CONSTRAINT `fk_export_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='导出日志表';

-- -----------------------------------------------------------------------------
-- 10. operation_logs —— 操作日志表（审计与排错）
-- -----------------------------------------------------------------------------
DROP TABLE IF EXISTS `operation_logs`;
CREATE TABLE `operation_logs` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`             BIGINT UNSIGNED  DEFAULT NULL                        COMMENT '操作用户（未登录时为 NULL）',
  `action`              VARCHAR(64)      NOT NULL                            COMMENT '操作类型',
  `target_type`         VARCHAR(32)      DEFAULT NULL                        COMMENT '对象类型：record/account/...',
  `target_id`           BIGINT UNSIGNED  DEFAULT NULL                        COMMENT '对象 ID',
  `payload`             JSON             DEFAULT NULL                        COMMENT '操作负载',
  `ip`                  VARCHAR(64)      DEFAULT NULL,
  `user_agent`          VARCHAR(255)     DEFAULT NULL,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_operation_logs_user_created` (`user_id`, `created_at`),
  KEY `idx_operation_logs_target`      (`target_type`, `target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='操作日志表';

-- -----------------------------------------------------------------------------
-- 视图：v_account_balance —— 账户余额实时计算
-- -----------------------------------------------------------------------------
-- 业务侧需要账户余额时，可直接 SELECT 该视图，避免冗余计算
DROP VIEW IF EXISTS `v_account_balance`;
CREATE VIEW `v_account_balance` AS
SELECT
  a.`id`,
  a.`uuid`,
  a.`user_id`,
  a.`book_id`,
  a.`name`,
  a.`type`,
  a.`initial_balance`,
  a.`initial_balance`
    + COALESCE(SUM(CASE WHEN r.`type` = 'income'  AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN r.`type` = 'expense' AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END), 0)
    + COALESCE(SUM(CASE WHEN r.`type` = 'transfer' AND r.`to_account_id` = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN r.`type` = 'transfer' AND r.`account_id`    = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END), 0)
    AS `balance`,
  a.`is_default`,
  a.`is_archived`,
  a.`sort_order`
FROM `accounts` a
LEFT JOIN `records` r ON r.`account_id` = a.`id` OR r.`to_account_id` = a.`id`
WHERE a.`deleted_at` IS NULL
GROUP BY a.`id`;

-- -----------------------------------------------------------------------------
-- 视图：v_monthly_summary —— 月度收支总览（对齐 PRD 报表）
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS `v_monthly_summary`;
CREATE VIEW `v_monthly_summary` AS
SELECT
  `user_id`,
  `book_id`,
  DATE_FORMAT(`record_date`, '%Y-%m') AS `month`,
  SUM(CASE WHEN `type` = 'expense' THEN `amount` ELSE 0 END) AS `total_expense`,
  SUM(CASE WHEN `type` = 'income'  THEN `amount` ELSE 0 END) AS `total_income`,
  SUM(CASE WHEN `type` = 'income'  THEN `amount` ELSE 0 END)
    - SUM(CASE WHEN `type` = 'expense' THEN `amount` ELSE 0 END) AS `balance`,
  COUNT(*) AS `record_count`
FROM `records`
WHERE `deleted_at` IS NULL
GROUP BY `user_id`, `book_id`, DATE_FORMAT(`record_date`, '%Y-%m');

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- 表结构创建完成
-- =============================================================================