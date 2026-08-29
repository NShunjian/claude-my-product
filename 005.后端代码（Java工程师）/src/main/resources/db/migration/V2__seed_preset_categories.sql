-- =============================================================================
-- V2 —— 预设分类(对齐前端 src/constants/categories.ts)
-- 9 个支出 + 5 个收入;user_id/book_id 都为 NULL,is_preset=1,
-- 真实部署不依赖 demo 用户注册即可用。
-- =============================================================================

INSERT INTO `categories`
  (`uuid`,            `user_id`, `type`,     `name`,  `icon`, `color`,    `is_preset`, `is_active`, `sort_order`)
VALUES
  ('preset-expense-餐饮', NULL, 'expense', '餐饮', '🍜', '#ED8936', 1, 1, 0),
  ('preset-expense-交通', NULL, 'expense', '交通', '🚗', '#4299E1', 1, 1, 1),
  ('preset-expense-购物', NULL, 'expense', '购物', '🛒', '#ED64A6', 1, 1, 2),
  ('preset-expense-娱乐', NULL, 'expense', '娱乐', '🎮', '#805AD5', 1, 1, 3),
  ('preset-expense-居住', NULL, 'expense', '居住', '🏠', '#8B6E4E', 1, 1, 4),
  ('preset-expense-医疗', NULL, 'expense', '医疗', '💊', '#E53E3E', 1, 1, 5),
  ('preset-expense-教育', NULL, 'expense', '教育', '📚', '#319795', 1, 1, 6),
  ('preset-expense-通讯', NULL, 'expense', '通讯', '📱', '#718096', 1, 1, 7),
  ('preset-expense-其他', NULL, 'expense', '其他', '📌', '#A0AEC0', 1, 1, 8),
  ('preset-income-工资',  NULL, 'income',  '工资', '💰', '#38A169', 1, 1, 0),
  ('preset-income-兼职',  NULL, 'income',  '兼职', '💼', '#4299E1', 1, 1, 1),
  ('preset-income-理财',  NULL, 'income',  '理财', '📈', '#ED8936', 1, 1, 2),
  ('preset-income-红包',  NULL, 'income',  '红包', '🧧', '#E53E3E', 1, 1, 3),
  ('preset-income-其他',  NULL, 'income',  '其他', '📌', '#A0AEC0', 1, 1, 4);
