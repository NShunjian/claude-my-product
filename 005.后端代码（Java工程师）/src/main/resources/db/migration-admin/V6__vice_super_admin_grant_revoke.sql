-- V6: 把 role:grant / role:revoke 加回 vice_super_admin
--
-- 背景:
--   V4 引入 vice_super_admin 时,从其权限集合里剔除了 role:grant / role:revoke,
--   当时意图是"主超管独占角色治理"。
--   但用户后续明确:副超管可以授权/撤销 admin / vice_admin / vice_super_admin
--   (只是不能授 super_admin),所以这两个权限要还回去。
--
-- 配套变更:
--   - AdminUserService.grantRole 已有"vice_super_admin 不能授 super_admin"的硬规则,
--     此迁移让 controller 层的 role:grant / role:revoke 校验不再 403。
--   - controller @RequiresPermission 已统一成 role:grant / role:revoke(V5 注释里
--     解释了 user:grant_role 的历史错误命名)。

SET NAMES utf8mb4;

INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'vice_super_admin'
     AND p.`code` IN ('role:grant', 'role:revoke')
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.`role_id` = r.id AND arp2.`permission_id` = p.id
     );

-- ponytail:用 NOT EXISTS 防重复插入,允许迁移被多次运行而不报错。
-- 验证:vice_super_admin 现在应有 18 + 2 = 20 权限。
