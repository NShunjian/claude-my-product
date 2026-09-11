-- =============================================================================
-- V10__money_audit_fixes.sql  (重写为幂等版)
-- 金额核算审计修复(2026-09)。
--
-- 本迁移在 2026-09-10 首次运行触发器/trigger 内子查询超时(虽然实际全部 DDL
-- 和数据回填都成功落库,但 Flyway 误报 success=0,导致后续启动阻塞)。
-- 修法见 [[flyway-v10-false-negative-recovery]]:flyway repair 删除失败行 +
-- 本文件改写为完全幂等,任何状态(全新 DB / 半成品 DB)都能 re-run 通过。
--
-- 幂等性策略:
--   - DROP TRIGGER / DROP VIEW / DROP FUNCTION 用原生 IF EXISTS(MySQL 原生支持)
--   - DROP COLUMN / DROP INDEX / DROP CHECK / ADD CONSTRAINT(CHECK)无原生 IF EXISTS,
--     MySQL 9.7 仍报语法错。用 INFORMATION_SCHEMA 查询 + PREPARE/EXECUTE 动态 SQL。
--   - MODIFY COLUMN / UPDATE 是天然幂等
--
-- 内容:
--   1. records.transfer CHECK(account_id != to_account_id)
--   2. records.month_key generated column + 复合索引
--   3. accounts.current_balance 自动同步 trigger(A/I/U/D)
--   4. budgets 表 amount > 0 / alert_threshold 范围 CHECK + 列类型收紧
--   5. v_monthly_netcashflow 视图
--   6. accounts.initial_balance / current_balance 加 COMMENT
--   7. 一次性数据回填(天然幂等)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. transfer 不变量 CHECK
-- -----------------------------------------------------------------------------
SET @exists := (SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
                WHERE CONSTRAINT_SCHEMA = DATABASE()
                  AND CONSTRAINT_NAME = 'chk_records_transfer_distinct_accounts');
SET @ddl := IF(@exists = 0,
  'ALTER TABLE `records` ADD CONSTRAINT `chk_records_transfer_distinct_accounts` CHECK (`type` <> ''transfer'' OR `account_id` <> `to_account_id`)',
  'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 2. records.month_key generated column + 复合索引
-- -----------------------------------------------------------------------------
SET @exists := (SELECT COUNT(*) FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'records'
                  AND COLUMN_NAME = 'month_key');
SET @ddl := IF(@exists = 0,
  'ALTER TABLE `records` ADD COLUMN `month_key` CHAR(7) GENERATED ALWAYS AS (DATE_FORMAT(`record_date`, ''%Y-%m'')) STORED',
  'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- idx_records_user_book_month
SET @exists := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'records'
                  AND INDEX_NAME = 'idx_records_user_book_month');
SET @ddl := IF(@exists = 0,
  'CREATE INDEX `idx_records_user_book_month` ON `records` (`user_id`, `book_id`, `month_key`)',
  'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- idx_records_book_month
SET @exists := (SELECT COUNT(*) FROM information_schema.STATISTICS
                WHERE TABLE_SCHEMA = DATABASE()
                  AND TABLE_NAME = 'records'
                  AND INDEX_NAME = 'idx_records_book_month');
SET @ddl := IF(@exists = 0,
  'CREATE INDEX `idx_records_book_month` ON `records` (`book_id`, `month_key`)',
  'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 3. current_balance 自动同步 trigger
--    DROP TRIGGER IF EXISTS 是 MySQL 原生支持的,DROP + CREATE 一起就是幂等的。
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_records_ai_sync_balance`;
CREATE TRIGGER `trg_records_ai_sync_balance`
AFTER INSERT ON `records` FOR EACH ROW
UPDATE `accounts` a
   SET a.`current_balance` = a.`initial_balance`
     + COALESCE((
         SELECT SUM(CASE WHEN r.`type` = 'income'  AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              - SUM(CASE WHEN r.`type` = 'expense' AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              + SUM(CASE WHEN r.`type` = 'transfer' AND r.`to_account_id` = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              - SUM(CASE WHEN r.`type` = 'transfer' AND r.`account_id`   = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
           FROM `records` r
          WHERE r.`account_id` = a.`id` OR r.`to_account_id` = a.`id`
       ), 0)
 WHERE a.`id` IN (NEW.`account_id`, NEW.`to_account_id`);

DROP TRIGGER IF EXISTS `trg_records_au_sync_balance`;
CREATE TRIGGER `trg_records_au_sync_balance`
AFTER UPDATE ON `records` FOR EACH ROW
UPDATE `accounts` a
   SET a.`current_balance` = a.`initial_balance`
     + COALESCE((
         SELECT SUM(CASE WHEN r.`type` = 'income'  AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              - SUM(CASE WHEN r.`type` = 'expense' AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              + SUM(CASE WHEN r.`type` = 'transfer' AND r.`to_account_id` = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              - SUM(CASE WHEN r.`type` = 'transfer' AND r.`account_id`   = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
           FROM `records` r
          WHERE r.`account_id` = a.`id` OR r.`to_account_id` = a.`id`
       ), 0)
 WHERE a.`id` IN (NEW.`account_id`, NEW.`to_account_id`,
                  OLD.`account_id`, OLD.`to_account_id`);

DROP TRIGGER IF EXISTS `trg_records_ad_sync_balance`;
CREATE TRIGGER `trg_records_ad_sync_balance`
AFTER DELETE ON `records` FOR EACH ROW
UPDATE `accounts` a
   SET a.`current_balance` = a.`initial_balance`
     + COALESCE((
         SELECT SUM(CASE WHEN r.`type` = 'income'  AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              - SUM(CASE WHEN r.`type` = 'expense' AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              + SUM(CASE WHEN r.`type` = 'transfer' AND r.`to_account_id` = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              - SUM(CASE WHEN r.`type` = 'transfer' AND r.`account_id`   = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
           FROM `records` r
          WHERE r.`account_id` = a.`id` OR r.`to_account_id` = a.`id`
       ), 0)
 WHERE a.`id` IN (OLD.`account_id`, OLD.`to_account_id`);

-- -----------------------------------------------------------------------------
-- 4. budgets 表约束(amount > 0、alert_threshold 范围 + 列类型收紧)
-- -----------------------------------------------------------------------------
SET @exists := (SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
                WHERE CONSTRAINT_SCHEMA = DATABASE()
                  AND CONSTRAINT_NAME = 'chk_budgets_amount_positive');
SET @ddl := IF(@exists = 0,
  'ALTER TABLE `budgets` ADD CONSTRAINT `chk_budgets_amount_positive` CHECK (`amount` > 0)',
  'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- alert_threshold 从 DECIMAL(5,2) 收紧到 DECIMAL(4,4)
-- 先把越界数据洗回合法范围(若有脏数据),再 MODIFY(MODIFY 本身幂等)
UPDATE `budgets` SET `alert_threshold` = 1.0000 WHERE `alert_threshold` > 1.0000;
UPDATE `budgets` SET `alert_threshold` = 0.0000 WHERE `alert_threshold` < 0.0000;

ALTER TABLE `budgets`
  MODIFY COLUMN `alert_threshold` DECIMAL(4,4) NOT NULL DEFAULT 0.8000;

SET @exists := (SELECT COUNT(*) FROM information_schema.CHECK_CONSTRAINTS
                WHERE CONSTRAINT_SCHEMA = DATABASE()
                  AND CONSTRAINT_NAME = 'chk_budgets_alert_threshold_range');
SET @ddl := IF(@exists = 0,
  'ALTER TABLE `budgets` ADD CONSTRAINT `chk_budgets_alert_threshold_range` CHECK (`alert_threshold` >= 0 AND `alert_threshold` <= 1)',
  'DO 0');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 5. 新增 v_monthly_netcashflow 视图(DROP + CREATE 是幂等的)
-- -----------------------------------------------------------------------------
DROP VIEW IF EXISTS `v_monthly_netcashflow`;
CREATE VIEW `v_monthly_netcashflow` AS
SELECT
  `user_id`,
  `book_id`,
  `month_key`                                                   AS `month`,
  SUM(CASE WHEN `type` = 'expense' AND `deleted_at` IS NULL THEN `amount` ELSE 0 END) AS `total_expense`,
  SUM(CASE WHEN `type` = 'income'  AND `deleted_at` IS NULL THEN `amount` ELSE 0 END) AS `total_income`,
  SUM(CASE WHEN `type` = 'income'  AND `deleted_at` IS NULL THEN `amount` ELSE 0 END)
    - SUM(CASE WHEN `type` = 'expense' AND `deleted_at` IS NULL THEN `amount` ELSE 0 END) AS `net_cashflow`,
  SUM(CASE WHEN `type` = 'transfer' AND `deleted_at` IS NULL THEN 1 ELSE 0 END)        AS `transfer_count`,
  COUNT(*) AS `record_count`
FROM `records`
WHERE `deleted_at` IS NULL
GROUP BY `user_id`, `book_id`, `month_key`;

-- -----------------------------------------------------------------------------
-- 6. accounts.initial_balance / current_balance 加 COMMENT(MODIFY 幂等)
-- -----------------------------------------------------------------------------
ALTER TABLE `accounts`
  MODIFY COLUMN `initial_balance` DECIMAL(14,2) NOT NULL DEFAULT 0.00
    COMMENT '账户开户初始余额,创建后业务上不可变(改要走 update API 显式 set)',
  MODIFY COLUMN `current_balance` DECIMAL(14,2) NOT NULL DEFAULT 0.00
    COMMENT '当前余额冗余缓存,由 trg_records_ai/au/ad_sync_balance 自动同步自 v_account_balance 表达式';

-- -----------------------------------------------------------------------------
-- 7. 一次性数据回填(UPDATE 天然幂等,trigger 也会自动维护)
-- -----------------------------------------------------------------------------
UPDATE `accounts` a
   SET a.`current_balance` = a.`initial_balance`
     + COALESCE((
         SELECT SUM(CASE WHEN r.`type` = 'income'  AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              - SUM(CASE WHEN r.`type` = 'expense' AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              + SUM(CASE WHEN r.`type` = 'transfer' AND r.`to_account_id` = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
              - SUM(CASE WHEN r.`type` = 'transfer' AND r.`account_id`   = a.`id` AND r.`deleted_at` IS NULL THEN r.`amount` ELSE 0 END)
           FROM `records` r
          WHERE r.`account_id` = a.`id` OR r.`to_account_id` = a.`id`
       ), 0)
 WHERE a.`deleted_at` IS NULL;
