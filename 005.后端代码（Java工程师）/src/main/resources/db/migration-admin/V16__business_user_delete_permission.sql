-- V16: 业务用户批量删除权限
--
-- 背景:
--   admin / super_admin / vice_super_admin 长期能「启停 + 重置密码」业务用户,
--   但没删除权限 —— 测账号 / 异常账号无法清理,只能把 status=0 闲置。
--   实际日常管理需求:批量勾选多个测试账号一次删掉(走 @TableLogic 软删)。
--
-- 方案:
--   1. 新增 business_user:delete 权限
--   2. 只绑给 admin(super_admin / vice_super_admin 由 V1 cross join 自动覆盖)
--   3. viewer 不加(只能 list / view,不能删)
--
-- 边界:
--   - 删除走 MyBatis-Plus @TableLogic,自动 deleted_at = NOW(),可恢复
--   - 不 bump token_version —— 已软删用户登录会被 @TableLogic 自动过滤,
--     根本走不到 JWT 校验这一步(SELECT user WHERE deleted_at IS NULL 拿不到)
--   - audit action: business_user.batch_delete
--   - 单次最多 100 ids(后端校验,前端 UI 也按当前页选)
--
-- 前端 AdminBusinessUsers.tsx 加 checkbox 列 + header 「已选 N 项」「批量删除」按钮,
-- 走 POST /api/admin/business-users/batch-delete { ids: number[] }。

SET NAMES utf8mb4;

-- 0. 诊断(运行后可注释)
-- SELECT r.code AS role, p.code AS perm
--   FROM admin_role_permissions arp
--   JOIN admin_roles       r ON arp.role_id       = r.id
--   JOIN admin_permissions p ON arp.permission_id = p.id
--  WHERE p.code = 'business_user:delete'
--  ORDER BY r.code;

-- 1. 新增权限
INSERT INTO `admin_permissions` (`code`, `name`, `resource`, `action`)
  SELECT 'business_user:delete', '批量删除业务用户', 'business_user', 'delete'
   WHERE NOT EXISTS (SELECT 1 FROM `admin_permissions` WHERE `code` = 'business_user:delete');

-- 2. 把权限绑给 admin(super_admin / vice_super_admin 由 V1 baseline 跨连自动覆盖)
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'admin'
     AND p.`code` = 'business_user:delete'
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.role_id       = r.id
          AND arp2.permission_id = p.id
     );

-- 验证:
--   admin / super_admin / vice_super_admin 都有 business_user:delete
--   viewer 没有