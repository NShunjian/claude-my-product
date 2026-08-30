-- V18: 管理员账号删除权限
--
-- 背景:
--   业务用户已有 batch_delete(V16+V17),管理员账号一直没有删除入口,只能 status=0 闲置。
--   实际日常需求:批量勾选多个 test 账号一次清掉(走 @TableLogic 软删,可恢复)。
--
-- 方案:
--   1. 新增 admin_user:delete 权限
--   2. 显式 NOT EXISTS 给 super_admin / vice_super_admin / admin 各 INSERT 一次
--      (V1 baseline 跨连只跑一次,新增权限不会自动落给已存在的角色 — V17 注释里已写明此约定)
--   3. viewer 不加(只能 list / view,不能删)
--
-- 边界:
--   - 删除走 MyBatis-Plus @TableLogic,自动 deleted_at = NOW(),可恢复
--   - 不能删自己(后端抛 ADMIN_PERMISSION_DENIED,前端按钮也禁用)
--   - 不能删最后一个 super_admin(V13 不变式:全局至多 1 个 super_admin)
--   - 删除时 bump token_version 作废该账号 JWT,被删者所有 session 立即失效
--   - audit action: admin_user.delete / admin_user.batch_delete
--   - 批量单次最多 100 ids(后端校验)

SET NAMES utf8mb4;

-- 1. 新增权限
INSERT INTO `admin_permissions` (`code`, `name`, `resource`, `action`)
  SELECT 'admin_user:delete', '删除管理员账号', 'admin_user', 'delete'
   WHERE NOT EXISTS (SELECT 1 FROM `admin_permissions` WHERE `code` = 'admin_user:delete');

-- 2. 显式绑给 super_admin
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'super_admin'
     AND p.`code` = 'admin_user:delete'
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.role_id       = r.id
          AND arp2.permission_id = p.id
     );

-- 3. 显式绑给 vice_super_admin
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'vice_super_admin'
     AND p.`code` = 'admin_user:delete'
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.role_id       = r.id
          AND arp2.permission_id = p.id
     );

-- 4. 显式绑给 admin
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'admin'
     AND p.`code` = 'admin_user:delete'
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.role_id       = r.id
          AND arp2.permission_id = p.id
     );

-- 验证:
--   super_admin / vice_super_admin / admin 都有 admin_user:delete
--   viewer 没有