-- V2: 新增 user:create 权限 —— 仅 super_admin 持有
-- 背景:admin 库独立后,需要 API 路径建新管理员账号,不能再靠 ENV bootstrap
-- 一条条 seed。

INSERT INTO `admin_permissions` (`code`, `name`, `resource`, `action`) VALUES
  ('user:create', '创建管理员', 'user', 'create');

-- 只授给 super_admin:admin / viewer 仍不能造新 admin
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'super_admin'
     AND p.`code` = 'user:create';