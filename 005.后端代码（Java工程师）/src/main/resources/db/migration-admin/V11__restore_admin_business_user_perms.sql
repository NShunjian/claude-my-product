-- V11: 还原 admin 的业务用户管理权限
--
-- 背景:
--   V9 误把 admin 的全部 4 个 business_user:* 撤了,导致 admin 侧边栏
--   看不到「业务用户」菜单,业务用户没人管(只剩 super_admin/vice_super_admin)。
--
-- 正确语义(V9 应该只增不减):
--   viewer         → + business_user:list / business_user:view(只读)
--   admin          → 保持原状(全权)
--   vice_super_admin / super_admin → 不动
--
-- 本迁移:把 admin 的 4 个 business_user:* 还回去 (NOT EXISTS 兜底,V10 之后 admin 若已有则跳过)
--
-- ponytail: 这是 V9 的补丁,而不是改 V9 本身 — Flyway 不会回滚已执行的迁移。

SET NAMES utf8mb4;

-- 0. 诊断(运行后可注释)
-- SELECT r.code AS role, p.code AS perm
--   FROM admin_role_permissions arp
--   JOIN admin_roles r        ON r.id = arp.role_id
--   JOIN admin_permissions p  ON p.id = arp.permission_id
--  WHERE p.code LIKE 'business_user:%'
--  ORDER BY r.code, p.code;

-- 1. 把 4 个 business_user:* 还给 admin
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'admin'
     AND p.`code` IN ('business_user:list', 'business_user:view',
                      'business_user:disable', 'business_user:reset_password')
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.role_id       = r.id
          AND arp2.permission_id = p.id
     );

-- 验证:
--   admin 重新拿到全部 4 个 business_user:*
--   viewer 仍只有 list + view(V9 的成果保留)
--   super_admin / vice_super_admin 不动
