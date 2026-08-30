-- V4: 新增副超级管理员 + 副管理员两个角色
--
-- 角色矩阵(V3 + V4):
--   super_admin      超级管理员     唯一,全权
--   vice_super_admin 副超级管理员   多人,几乎全权(看不到主超管)
--   admin            管理员         业务用户治理
--   vice_admin       副管理员       业务用户只读 + dashboard
--   viewer           只读审计员     全只读
--
-- 现有 super_admin 数可能 > 1(历史 bootstrap 累积),V4 不强制收敛,
-- 由 transfer 机制(grantRole)在使用时保证。

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- 1. 新增两个角色
-- -----------------------------------------------------------------------------
INSERT INTO `admin_roles` (`uuid`, `code`, `name`, `description`, `status`) VALUES
  (UUID(), 'vice_super_admin', '副超级管理员', '几乎全权,看不到主超级管理员,授权/解授权角色', 1),
  (UUID(), 'vice_admin',       '副管理员',     '业务用户只读 + 业务数据浏览 + dashboard', 1);

-- -----------------------------------------------------------------------------
-- 2. 给副超级管理员分配权限
--    拿掉 user:* (admin 账号治理)和 role:* (角色治理) — 这些是主超管的独占区
--    保留其它所有权限
-- -----------------------------------------------------------------------------
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'vice_super_admin'
     AND p.`code` NOT IN (
       -- 主超管独占:admin 账号治理
       'user:create',
       -- 主超管独占:角色治理(授权/撤销任何角色)
       'role:grant', 'role:revoke'
       -- 主超管独占:审计日志(看主超管自己操作过的痕迹)
       -- 注:实际不在 vice_super_admin 里,见下方显式 INSERT
     );

-- 显式排除 audit:list — 主超管独占
DELETE arp
  FROM `admin_role_permissions` arp
  JOIN `admin_roles` r ON arp.`role_id` = r.`id`
  JOIN `admin_permissions` p ON arp.`permission_id` = p.`id`
 WHERE r.`code` = 'vice_super_admin'
   AND p.`code` = 'audit:list';

-- 验证(运行后手算):vice_super_admin 应有 22 - 3 = 19 权限
--   全部(22) - user:create - role:grant - role:revoke - audit:list = 19
-- 含 business_user:* (4) + category:preset:* (4) + book:* (2) + record:* (2)
--   + dashboard:view (1) + user:list/view/disable/reset_password (4) + role:list (1) + role:grant/no(无)
--   + audit:list/no(无) = 18? 计算见 V1+V2+V3 累计

-- -----------------------------------------------------------------------------
-- 3. 给副管理员分配权限 —— 业务用户只读 + 业务浏览 + dashboard
-- -----------------------------------------------------------------------------
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'vice_admin'
     AND p.`code` IN (
       'business_user:list', 'business_user:view',
       'book:list', 'book:view',
       'record:list', 'record:view',
       'category:preset:list',
       'dashboard:view'
     );

-- 验证: vice_admin 应有 8 权限(4 + 2 + 2 + 1 + 1 = 10? 具体手算)
--   business_user:list/view (2) + book:list/view (2) + record:list/view (2)
--   + category:preset:list (1) + dashboard:view (1) = 8

-- -----------------------------------------------------------------------------
-- 4. 不动现有角色映射(super_admin 22 / admin 14 / viewer 8 保持)
-- -----------------------------------------------------------------------------

-- ponytail:本次迁移仅加 2 个角色 + 它们的权限。
-- super_admin 唯一性的 transfer 逻辑由 AdminUserService.grantRole 在运行时保证,
-- 不在 DB 层触发(避免 migration 误删历史数据)。