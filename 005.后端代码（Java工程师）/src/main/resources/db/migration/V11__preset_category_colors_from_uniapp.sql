-- =============================================================================
-- V11 —— 预设分类 color 对齐 uniapp token 表(柔和色,modern palette)
-- ponytail: 之前 V2 seed 的 color 字段前端从不读(前端用本地 token 表),
-- 现在所有端都走后端 color,所以预设色以本迁移为准。
-- 自定义分类(is_preset=0)的 color 不动,保留用户自选色。
--
-- 注意:DB 里实际 uuid 不带 'preset-' 前缀(见 V2 seed 写入 vs 实际查询),
-- 是 'expense-餐饮' / 'income-工资' 这种形式(老迁移脚本剥过前缀)。
-- =============================================================================

UPDATE `categories` SET `color` = '#4299E1' WHERE `uuid` = 'expense-餐饮';
UPDATE `categories` SET `color` = '#06B6D4' WHERE `uuid` = 'expense-交通';
UPDATE `categories` SET `color` = '#ED64A6' WHERE `uuid` = 'expense-购物';
UPDATE `categories` SET `color` = '#805AD5' WHERE `uuid` = 'expense-娱乐';
UPDATE `categories` SET `color` = '#8B6E4E' WHERE `uuid` = 'expense-居住';
UPDATE `categories` SET `color` = '#319795' WHERE `uuid` = 'expense-医疗';
UPDATE `categories` SET `color` = '#F59E0B' WHERE `uuid` = 'expense-教育';
UPDATE `categories` SET `color` = '#6366F1' WHERE `uuid` = 'expense-通讯';
UPDATE `categories` SET `color` = '#727782' WHERE `uuid` = 'expense-其他';

UPDATE `categories` SET `color` = '#10b981' WHERE `uuid` = 'income-工资';
UPDATE `categories` SET `color` = '#06B6D4' WHERE `uuid` = 'income-兼职';
UPDATE `categories` SET `color` = '#6366F1' WHERE `uuid` = 'income-理财';
UPDATE `categories` SET `color` = '#ED64A6' WHERE `uuid` = 'income-红包';
UPDATE `categories` SET `color` = '#727782' WHERE `uuid` = 'income-其他';
-- 兜底:历史迁移漏改的收入"其他",uuid 仍带 'preset-' 前缀
UPDATE `categories` SET `color` = '#727782' WHERE `uuid` = 'preset-income-其他';
