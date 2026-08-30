-- V3: 业务用户 vs admin 账号权限分离
-- 目标:
--   super_admin: 管 admin 账号 + 管业务用户
--   admin:       仅管业务用户(看不到 admin 账号)
--   viewer:      不动

-- 1. 新增 4 个 business_user:* 权限
INSERT INTO `admin_permissions` (`code`, `name`, `resource`, `action`) VALUES
  ('business_user:list',           '业务用户列表',     'business_user', 'list'),
  ('business_user:view',           '业务用户详情',     'business_user', 'view'),
  ('business_user:disable',        '启停业务用户',     'business_user', 'disable'),
  ('business_user:reset_password', '重置业务用户密码', 'business_user', 'reset_password');

-- 2. 把 business_user:* 绑给 super_admin + admin 两角色
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` IN ('super_admin', 'admin')
     AND p.`code` IN ('business_user:list', 'business_user:view',
                      'business_user:disable', 'business_user:reset_password');

-- 3. 把 user:list / user:view / user:disable / user:reset_password 从 admin 角色剥离
--    (super_admin 保留 user:create 由 V2 已加,保留 user:* 全套)
DELETE arp
  FROM `admin_role_permissions` arp
  JOIN `admin_roles`       r  ON arp.`role_id`       = r.`id`
  JOIN `admin_permissions` p  ON arp.`permission_id` = p.`id`
 WHERE r.`code` = 'admin'
   AND p.`code` IN ('user:list', 'user:view', 'user:disable', 'user:reset_password');

-- 验证:
--   super_admin: 全 22 权限 (18 - 0 + 4)
--   admin:       18 权限 (原 14 - 4 剥离 + 4 新增 = 14)
--                 含 business_user:* (4) + category:preset:* (4) + book:* (2)
--                 + record:* (2) + dashboard:view (1) + user:create(没有)
--                 + role:* (没有) + audit:list (没有) + user:* (没有)
--                 = 14 ✓
--   viewer:      8 不动

-- ponytail:这里不更新 V1 baseline —— 允许"独立迁移"叠加,后续环境可直接
-- 从头跑 V1 → V3 不需要中间状态。如果未来再有 V4 / V5,各自独立写。