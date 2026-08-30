-- V9: 业务用户管理权限重切
--
-- 用户最新决策:
--   只读审计员 (viewer) — 业务用户只读 (列表 + 详情)
--   管理员     (admin)   — 不再管业务用户,移出业务用户菜单
--   副超管     (vice_super_admin) — 不动 (保留全部 4 个 business_user:* 权限)
--   超管       (super_admin)     — 不动
--
-- 本迁移两步:
--   a. 把 business_user:list / business_user:view 加给 viewer (NOT EXISTS 兜底,已加过也不报错)
--   b. 把 admin 的全部 4 个 business_user:* 权限撤掉
--
-- ponytail: 操作前先 SELECT 看一眼目标行数,确认只动 admin/viewer 不波及其它角色。

SET NAMES utf8mb4;

-- 0. 诊断(运行后可注释掉)
-- SELECT r.code AS role, p.code AS perm
--   FROM admin_role_permissions arp
--   JOIN admin_roles r        ON r.id = arp.role_id
--   JOIN admin_permissions p  ON p.id = arp.permission_id
--  WHERE p.code LIKE 'business_user:%'
--  ORDER BY r.code, p.code;

-- 1. 给 viewer 加只读权限(list + view)
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'viewer'
     AND p.`code` IN ('business_user:list', 'business_user:view')
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.role_id       = r.id
          AND arp2.permission_id = p.id
     );

-- 2. 撤掉 admin 的全部 business_user:* (list/view/disable/reset_password)
DELETE arp FROM `admin_role_permissions` arp
  JOIN `admin_roles`       r ON r.id = arp.role_id
  JOIN `admin_permissions` p ON p.id = arp.permission_id
 WHERE r.`code` = 'admin'
   AND p.`code` LIKE 'business_user:%';

-- 验证:
--   viewer 应有 business_user:list + business_user:view,没有 disable/reset_password
--   admin  应完全没有 business_user:*
--   super_admin / vice_super_admin 保持原状 (4 个 business_user:* 都在)
