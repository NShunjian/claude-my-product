-- V10: viewer 不能再看「管理员账号」页
--
-- 用户最新决策:
--   只读审计员 (viewer) — 不允许浏览后台账号列表/详情
--   原因:管理员账号是内部治理主体,审计员不需要知道谁有管理权
--         (避免泄漏组织结构 / 越权猜测管理员)
--
-- 本迁移:撤掉 viewer 的 user:list / user:view 两个权限
-- 效果:AdminLayout 的 NAV 项 `{ to: '/users', code: 'user:list' }` 自动隐藏;
--       viewer 直接敲 /users URL 也会被 AdminAuthInterceptor 的 @RequiresPermission 拦下 403。
--
-- ponytail: 操作前后 SELECT 一下,确认只动 viewer 一行,不动 admin/super_admin。

SET NAMES utf8mb4;

-- 0. 诊断(运行后可注释)
-- SELECT r.code AS role, p.code AS perm
--   FROM admin_role_permissions arp
--   JOIN admin_roles r        ON r.id = arp.role_id
--   JOIN admin_permissions p  ON p.id = arp.permission_id
--  WHERE r.code = 'viewer' AND p.code LIKE 'user:%'
--  ORDER BY p.code;

-- 1. 撤掉 viewer 的 user:list / user:view
DELETE arp FROM `admin_role_permissions` arp
  JOIN `admin_roles`       r ON r.id = arp.role_id
  JOIN `admin_permissions` p ON p.id = arp.permission_id
 WHERE r.`code` = 'viewer'
   AND p.`code` IN ('user:list', 'user:view');

-- 验证:viewer 在 user:* 上应为 0 行 (viewer 没有任何 user 权限)
--   其它角色保持原状
