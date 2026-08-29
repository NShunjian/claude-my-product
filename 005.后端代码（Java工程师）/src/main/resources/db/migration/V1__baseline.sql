-- =============================================================================
-- 轻账 (QingZhang) V1 baseline —— 与 004.DBA/01_schema_qingzhang.sql 对齐
-- -----------------------------------------------------------------------------
-- Flyway baseline。后续 schema 变更加 V2__xxx.sql / V3__xxx.sql,禁止改 V1。
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;
SET SQL_MODE = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

-- 1. users
CREATE TABLE `users` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT             COMMENT '物理主键',
  `uuid`                CHAR(36)         NOT NULL                            COMMENT '业务主键 UUID',
  `username`            VARCHAR(20)      NOT NULL                            COMMENT '登录用户名,唯一',
  `password_hash`       VARCHAR(128)     NOT NULL                            COMMENT '密码哈希值(BCrypt)',
  `display_name`        VARCHAR(50)      DEFAULT NULL                        COMMENT '昵称',
  `avatar`              MEDIUMTEXT       DEFAULT NULL                        COMMENT '头像 URL 或 dataURL',
  `gender`              ENUM('male','female','other') DEFAULT NULL          COMMENT '性别',
  `age`                 TINYINT UNSIGNED DEFAULT NULL                        COMMENT '年龄(0-120)',
  `email`               VARCHAR(100)     DEFAULT NULL                        COMMENT '邮箱(V1.1 预留)',
  `phone`               VARCHAR(20)      DEFAULT NULL                        COMMENT '手机号(V1.1 预留)',
  `status`              TINYINT          NOT NULL DEFAULT 1                  COMMENT '状态:1=启用 0=禁用',
  `last_login_at`       DATETIME(3)      DEFAULT NULL                        COMMENT '最近登录时间',
  `last_login_ip`       VARCHAR(64)      DEFAULT NULL                        COMMENT '最近登录 IP',
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`          DATETIME(3)      DEFAULT NULL                        COMMENT '软删除时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_uuid`     (`uuid`),
  UNIQUE KEY `uk_users_username` (`username`),
  KEY `idx_users_created_at`    (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- 2. books
CREATE TABLE `books` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `owner_id`            BIGINT UNSIGNED  NOT NULL,
  `name`                VARCHAR(50)      NOT NULL,
  `description`         VARCHAR(255)     DEFAULT NULL,
  `type`                ENUM('personal','shared','business') NOT NULL DEFAULT 'personal',
  `currency`            CHAR(3)          NOT NULL DEFAULT 'CNY',
  `is_default`          TINYINT          NOT NULL DEFAULT 0,
  `is_archived`         TINYINT          NOT NULL DEFAULT 0,
  `sort_order`          INT              NOT NULL DEFAULT 0,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`          DATETIME(3)      DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_books_uuid` (`uuid`),
  KEY `idx_books_owner`        (`owner_id`, `is_archived`),
  KEY `idx_books_default`      (`owner_id`, `is_default`),
  CONSTRAINT `fk_books_owner`   FOREIGN KEY (`owner_id`) REFERENCES `users` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账本表';

-- 3. book_members
CREATE TABLE `book_members` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `book_id`             BIGINT UNSIGNED  NOT NULL,
  `user_id`             BIGINT UNSIGNED  NOT NULL,
  `role`                ENUM('owner','admin','editor','viewer') NOT NULL DEFAULT 'editor',
  `joined_at`           DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `invited_by`          BIGINT UNSIGNED  DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_book_member` (`book_id`, `user_id`),
  KEY `idx_book_members_user` (`user_id`),
  CONSTRAINT `fk_book_members_book` FOREIGN KEY (`book_id`) REFERENCES `books` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_book_members_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账本成员(V1.1)';

-- 4. categories
CREATE TABLE `categories` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `user_id`             BIGINT UNSIGNED  DEFAULT NULL                        COMMENT 'NULL 表示系统预设',
  `book_id`             BIGINT UNSIGNED  DEFAULT NULL                        COMMENT 'NULL 表示跨账本预设',
  `type`                ENUM('expense','income') NOT NULL,
  `name`                VARCHAR(10)      NOT NULL,
  `icon`                VARCHAR(32)      NOT NULL DEFAULT '',
  `color`               VARCHAR(16)      NOT NULL DEFAULT '#A0AEC0',
  `is_preset`           TINYINT          NOT NULL DEFAULT 0,
  `is_active`           TINYINT          NOT NULL DEFAULT 1,
  `sort_order`          INT              NOT NULL DEFAULT 0,
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

-- 5. accounts
CREATE TABLE `accounts` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `user_id`             BIGINT UNSIGNED  NOT NULL,
  `book_id`             BIGINT UNSIGNED  DEFAULT NULL,
  `name`                VARCHAR(20)      NOT NULL,
  `icon`                VARCHAR(32)      NOT NULL DEFAULT '💳',
  `type`                ENUM('cash','debit','credit','wallet','investment','other') NOT NULL DEFAULT 'wallet',
  `initial_balance`     DECIMAL(14,2)    NOT NULL DEFAULT 0.00,
  `current_balance`     DECIMAL(14,2)    NOT NULL DEFAULT 0.00,
  `currency`            CHAR(3)          NOT NULL DEFAULT 'CNY',
  `is_default`          TINYINT          NOT NULL DEFAULT 0,
  `is_archived`         TINYINT          NOT NULL DEFAULT 0,
  `sort_order`          INT              NOT NULL DEFAULT 0,
  `note`                VARCHAR(255)     DEFAULT NULL,
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

-- 6. records
CREATE TABLE `records` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `user_id`             BIGINT UNSIGNED  NOT NULL,
  `book_id`             BIGINT UNSIGNED  NOT NULL,
  `type`                ENUM('expense','income','transfer') NOT NULL,
  `category_id`         BIGINT UNSIGNED  DEFAULT NULL,
  `account_id`          BIGINT UNSIGNED  NOT NULL,
  `to_account_id`       BIGINT UNSIGNED  DEFAULT NULL,
  `amount`              DECIMAL(12,2)    NOT NULL,
  `currency`            CHAR(3)          NOT NULL DEFAULT 'CNY',
  `note`                VARCHAR(50)      DEFAULT NULL,
  `record_date`         DATE             NOT NULL,
  `source`              ENUM('manual','import','ocr','auto','sync') NOT NULL DEFAULT 'manual',
  `location`            VARCHAR(255)     DEFAULT NULL,
  `client_id`           VARCHAR(64)      DEFAULT NULL,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`          DATETIME(3)      DEFAULT NULL,
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

-- 7. record_attachments
CREATE TABLE `record_attachments` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `record_id`           BIGINT UNSIGNED  NOT NULL,
  `file_url`            VARCHAR(500)     NOT NULL,
  `file_type`           ENUM('image','pdf','audio','other') NOT NULL DEFAULT 'image',
  `file_size`           INT UNSIGNED     DEFAULT NULL,
  `ocr_raw`             JSON             DEFAULT NULL,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_record_attachments_uuid` (`uuid`),
  KEY `idx_record_attachments_record` (`record_id`),
  CONSTRAINT `fk_record_attachments_record` FOREIGN KEY (`record_id`) REFERENCES `records` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='账目附件表';

-- 8. budgets
CREATE TABLE `budgets` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `user_id`             BIGINT UNSIGNED  NOT NULL,
  `book_id`             BIGINT UNSIGNED  NOT NULL,
  `category_id`         BIGINT UNSIGNED  DEFAULT NULL,
  `amount`              DECIMAL(12,2)    NOT NULL,
  `period`              ENUM('monthly','yearly','weekly') NOT NULL DEFAULT 'monthly',
  `start_date`          DATE             NOT NULL,
  `end_date`            DATE             DEFAULT NULL,
  `alert_threshold`     DECIMAL(5,2)     NOT NULL DEFAULT 0.80,
  `is_active`           TINYINT          NOT NULL DEFAULT 1,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_budgets_uuid` (`uuid`),
  KEY `idx_budgets_user_period` (`user_id`, `period`, `is_active`),
  CONSTRAINT `fk_budgets_user`     FOREIGN KEY (`user_id`)     REFERENCES `users` (`id`)      ON DELETE CASCADE,
  CONSTRAINT `fk_budgets_book`     FOREIGN KEY (`book_id`)     REFERENCES `books` (`id`)      ON DELETE CASCADE,
  CONSTRAINT `fk_budgets_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='预算表(V2.0)';

-- 9. export_logs
CREATE TABLE `export_logs` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `uuid`                CHAR(36)         NOT NULL,
  `user_id`             BIGINT UNSIGNED  NOT NULL,
  `export_type`         ENUM('monthly','category','full','custom') NOT NULL,
  `file_name`           VARCHAR(255)     NOT NULL,
  `file_url`            VARCHAR(500)     DEFAULT NULL,
  `file_size`           INT UNSIGNED     DEFAULT NULL,
  `record_count`        INT UNSIGNED     NOT NULL DEFAULT 0,
  `filter_json`         JSON             DEFAULT NULL,
  `status`              ENUM('pending','success','failed') NOT NULL DEFAULT 'pending',
  `error_msg`           VARCHAR(500)     DEFAULT NULL,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_export_logs_uuid` (`uuid`),
  KEY `idx_export_logs_user_created` (`user_id`, `created_at`),
  CONSTRAINT `fk_export_logs_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='导出日志表';

-- 10. operation_logs
CREATE TABLE `operation_logs` (
  `id`                  BIGINT UNSIGNED  NOT NULL AUTO_INCREMENT,
  `user_id`             BIGINT UNSIGNED  DEFAULT NULL,
  `action`              VARCHAR(64)      NOT NULL,
  `target_type`         VARCHAR(32)      DEFAULT NULL,
  `target_id`           BIGINT UNSIGNED  DEFAULT NULL,
  `payload`             JSON             DEFAULT NULL,
  `ip`                  VARCHAR(64)      DEFAULT NULL,
  `user_agent`          VARCHAR(255)     DEFAULT NULL,
  `created_at`          DATETIME(3)      NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  KEY `idx_operation_logs_user_created` (`user_id`, `created_at`),
  KEY `idx_operation_logs_target`      (`target_type`, `target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='操作日志表';

-- -----------------------------------------------------------------------------
-- 视图:v_account_balance —— 账户余额实时计算(与前端 v_account_balance 对齐)
-- -----------------------------------------------------------------------------
CREATE VIEW `v_account_balance` AS
SELECT
  a.`id`,
  a.`uuid`,
  a.`user_id`,
  a.`book_id`,
  a.`name`,
  a.`type`,
  a.`icon`,
  a.`initial_balance`,
  a.`initial_balance`
    + COALESCE(SUM(CASE WHEN r.`type` = 'income'  AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN r.`type` = 'expense' AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END), 0)
    + COALESCE(SUM(CASE WHEN r.`type` = 'transfer' AND r.`to_account_id` = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN r.`type` = 'transfer' AND r.`account_id`    = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END), 0)
    AS `balance`,
  a.`currency`,
  a.`is_default`,
  a.`is_archived`,
  a.`sort_order`,
  a.`note`,
  a.`created_at`
FROM `accounts` a
LEFT JOIN `records` r ON r.`account_id` = a.`id` OR r.`to_account_id` = a.`id`
WHERE a.`deleted_at` IS NULL
GROUP BY a.`id`;

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
