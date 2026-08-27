-- =============================================================================
-- 轻账 (QingZhang) 初始化数据脚本
-- -----------------------------------------------------------------------------
-- 适用：MySQL 8.0+
-- 依赖：01_schema_qingzhang.sql
-- 内容：
--   1. demo 用户 + 个人账本（仅用于联调演示，可删除）
--   2. 预设分类（9 个支出 + 5 个收入，对齐 PRD V1.0 §4.1）
--   3. 默认 demo 账户（5 个，对齐前端 PRESET_ACCOUNTS）
-- 注意事项：
--   · 业务 UUID 是固定的，便于前后端/多端数据对齐
--   · 真实部署请把 demo 数据剔除后再执行
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 0. demo 用户（仅供联调）
-- -----------------------------------------------------------------------------
-- 密码：Demo@123
-- 哈希：bcrypt cost=10（与 src/utils/hash.ts 的 BCRYPT_COST 默认一致）
-- 上线请通过应用注册流程创建用户，不要直接写入明文密码。
INSERT INTO `users`
  (`uuid`, `username`, `password_hash`, `salt`, `display_name`, `status`)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'demo',
   '$2b$10$AfJ3JPyrjxiCRrFvT6MsyuDaEHOi6hjJ54ZEe6.KPvQIgxMWfTcp2',
   'bcrypt', '演示用户', 1);

-- -----------------------------------------------------------------------------
-- 1. demo 账本（每个用户一个默认个人账本）
-- -----------------------------------------------------------------------------
INSERT INTO `books`
  (`uuid`, `owner_id`, `name`, `description`, `type`, `currency`, `is_default`, `sort_order`)
SELECT
  '00000000-0000-0000-0000-0000000000a1',
  u.`id`,
  '个人账本',
  '默认个人账本',
  'personal',
  'CNY',
  1,
  0
FROM `users` u
WHERE u.`username` = 'demo';

-- -----------------------------------------------------------------------------
-- 2. 预设分类
-- -----------------------------------------------------------------------------
-- 2.1 支出分类（9 个，对齐前端 EXPENSE_CATEGORIES）
INSERT INTO `categories`
  (`uuid`,            `user_id`, `type`,     `name`,  `icon`, `color`,    `is_preset`, `is_active`, `sort_order`)
VALUES
  ('expense-餐饮',     NULL,    'expense', '餐饮',  '🍜',  '#ED8936',  1,          1,           0),
  ('expense-交通',     NULL,    'expense', '交通',  '🚗',  '#4299E1',  1,          1,           1),
  ('expense-购物',     NULL,    'expense', '购物',  '🛒',  '#ED64A6',  1,          1,           2),
  ('expense-娱乐',     NULL,    'expense', '娱乐',  '🎮',  '#805AD5',  1,          1,           3),
  ('expense-居住',     NULL,    'expense', '居住',  '🏠',  '#8B6E4E',  1,          1,           4),
  ('expense-医疗',     NULL,    'expense', '医疗',  '💊',  '#E53E3E',  1,          1,           5),
  ('expense-教育',     NULL,    'expense', '教育',  '📚',  '#319795',  1,          1,           6),
  ('expense-通讯',     NULL,    'expense', '通讯',  '📱',  '#718096',  1,          1,           7),
  ('expense-其他',     NULL,    'expense', '其他',  '📌',  '#A0AEC0',  1,          1,           8);

-- 2.2 收入分类（5 个，对齐前端 INCOME_CATEGORIES）
INSERT INTO `categories`
  (`uuid`,            `user_id`, `type`,     `name`,  `icon`, `color`,    `is_preset`, `is_active`, `sort_order`)
VALUES
  ('income-工资',      NULL,    'income',  '工资',  '💰',  '#38A169',  1,          1,           0),
  ('income-兼职',      NULL,    'income',  '兼职',  '💼',  '#4299E1',  1,          1,           1),
  ('income-理财',      NULL,    'income',  '理财',  '📈',  '#ED8936',  1,          1,           2),
  ('income-红包',      NULL,    'income',  '红包',  '🧧',  '#E53E3E',  1,          1,           3),
  ('income-其他',      NULL,    'income',  '其他',  '📌',  '#A0AEC0',  1,          1,           4);

-- -----------------------------------------------------------------------------
-- 3. 默认账户（5 个，对齐前端 PRESET_ACCOUNTS）
-- -----------------------------------------------------------------------------
INSERT INTO `accounts`
  (`uuid`,           `user_id`,  `book_id`,  `name`,     `icon`, `type`,    `initial_balance`, `current_balance`, `is_default`, `sort_order`)
SELECT
  'account-wechat',  u.`id`,    b.`id`,
  '微信支付',         '💳',     'wallet',    0.00,        0.00,        1,           0
FROM `users` u JOIN `books` b ON b.`owner_id` = u.`id`
WHERE u.`username` = 'demo';

INSERT INTO `accounts`
  (`uuid`,           `user_id`,  `book_id`,  `name`,     `icon`, `type`,    `initial_balance`, `current_balance`, `is_default`, `sort_order`)
SELECT
  'account-alipay',  u.`id`,    b.`id`,
  '支付宝',           '💳',     'wallet',    0.00,        0.00,        0,           1
FROM `users` u JOIN `books` b ON b.`owner_id` = u.`id`
WHERE u.`username` = 'demo';

INSERT INTO `accounts`
  (`uuid`,           `user_id`,  `book_id`,  `name`,     `icon`, `type`,    `initial_balance`, `current_balance`, `is_default`, `sort_order`)
SELECT
  'account-cash',    u.`id`,    b.`id`,
  '现金',             '💵',     'cash',      0.00,        0.00,        0,           2
FROM `users` u JOIN `books` b ON b.`owner_id` = u.`id`
WHERE u.`username` = 'demo';

INSERT INTO `accounts`
  (`uuid`,           `user_id`,  `book_id`,  `name`,     `icon`, `type`,    `initial_balance`, `current_balance`, `is_default`, `sort_order`)
SELECT
  'account-bank',    u.`id`,    b.`id`,
  '银行卡',           '🏦',     'debit',     0.00,        0.00,        0,           3
FROM `users` u JOIN `books` b ON b.`owner_id` = u.`id`
WHERE u.`username` = 'demo';

INSERT INTO `accounts`
  (`uuid`,           `user_id`,  `book_id`,  `name`,     `icon`, `type`,    `initial_balance`, `current_balance`, `is_default`, `sort_order`)
SELECT
  'account-credit',  u.`id`,    b.`id`,
  '信用卡',           '💳',     'credit',    0.00,        0.00,        0,           4
FROM `users` u JOIN `books` b ON b.`owner_id` = u.`id`
WHERE u.`username` = 'demo';

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================================
-- 初始化完成
-- =============================================================================