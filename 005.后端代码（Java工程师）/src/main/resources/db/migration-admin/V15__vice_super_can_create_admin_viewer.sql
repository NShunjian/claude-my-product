-- V15: vice_super_admin 也能 user:create(建 admin / viewer 账号)
--
-- 背景:
--   V7 起 user:create 权限只在 super_admin 角色 —— 副超管虽然有 dashboard:view +
--   user:* / role:* 等同等权限,但不能建新账号,只能找超管开。
--   用户反馈:super_admin 是单点(Singleton,V13 强制全局唯一),实际日常管理
--   副超管才是常态用户,要求也能建 admin / viewer 账号。
--
-- 方案:
--   - 给 vice_super_admin 加 user:create
--   - 后端 AdminUserService.create 按 actor 角色限制 roleCode 白名单:
--       super_admin      → roleCode ∈ {admin, vice_super_admin, viewer}
--       vice_super_admin → roleCode ∈ {admin, viewer}
--     super_admin 仍禁止通过 API 创建(V7 + V13 双重防线,这是 SQL/迁移层的事)
--   - 前端 AdminUsers.tsx 加"新建账号"按钮 + CreateUserModal
--
-- V12 trigger 自动 bump vice_super_admin 的 token_version —— 但 V15 只是
-- 加权限,不涉及 user_roles / role_permissions 变更,不需要 bump。NOT EXISTS
-- 兜底:若已加过(意外重跑),跳过。

SET NAMES utf8mb4;

-- 0. 诊断(运行后可注释)
-- SELECT r.code, p.code
--   FROM admin_role_permissions rp
--   JOIN admin_roles r ON r.id = rp.role_id
--   JOIN admin_permissions p ON p.id = rp.permission_id
--  WHERE p.code = 'user:create';

-- 1. 把 user:create 授予 vice_super_admin
INSERT INTO admin_role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM admin_roles r
  JOIN admin_permissions p ON p.code = 'user:create'
 WHERE r.code = 'vice_super_admin'
   AND NOT EXISTS (
     SELECT 1 FROM admin_role_permissions rp
      WHERE rp.role_id = r.id AND rp.permission_id = p.id
   );

-- 验证:
--   应看到 super_admin + vice_super_admin 两行 user:create
--   SELECT r.code, p.code
--     FROM admin_role_permissions rp
--     JOIN admin_roles r ON r.id = rp.role_id
--     JOIN admin_permissions p ON p.id = rp.permission_id
--    WHERE p.code = 'user:create' ORDER BY r.code;
