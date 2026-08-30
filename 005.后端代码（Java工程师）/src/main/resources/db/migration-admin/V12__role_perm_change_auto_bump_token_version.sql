-- V12: role_permission 变更自动踢出受影响账号
--
-- 背景:V9/V10/V11 改 admin_role_permissions 时,只动了角色与权限的映射,
--      持有旧 JWT 的用户还是按老 permissions claim 渲染 UI (AdminLayout 的
--      NAV 用 has('xxx:list') 判断),导致「管理员看不到菜单 / 突然看到菜单」
--      与新规则不符,只能手动 logout → login 才能生效。
--
-- 用户最新决策:角色-权限表 (admin_role_permissions) 任何 INSERT / DELETE
--              都自动 bump 该角色下所有 admin_users.token_version,
--              AdminAuthInterceptor 比对失败 → 401 → 前端强制重新登录。
--              业务代码不再需要手动 bump (updateStatus / grantRole /
--              revokeRole 里的现有 bump 是冗余但无害,保留不影响)。
--
-- 本迁移两步:
--   a. 写触发器 trg_arp_ai_bump / trg_arp_ad_bump
--   b. 兜底 bump:V9/V10/V11 已发生,补一次 UPDATE 让现存受影响账号
--      (viewer + admin) 老 JWT 立即失效
--
-- ponytail: 单语句触发器,不用 BEGIN...END,无需 DELIMITER 切换 —
--          Flyway JDBC 直送 MySQL 也能正确解析。

SET NAMES utf8mb4;

-- 0. 诊断(运行后可注释)
-- SELECT r.code AS role, p.code AS perm, COUNT(*) AS cnt
--   FROM admin_role_permissions arp
--   JOIN admin_roles r        ON r.id = arp.role_id
--   JOIN admin_permissions p  ON p.id = arp.permission_id
--  GROUP BY r.code, p.code
--  ORDER BY r.code, p.code;

-- -----------------------------------------------------------------------------
-- 1a. INSERT 触发器:新授权 → 该角色所有 admin_users.token_version +1
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_arp_ai_bump;
CREATE TRIGGER trg_arp_ai_bump
AFTER INSERT ON admin_role_permissions
FOR EACH ROW
UPDATE admin_users au
   SET au.token_version = au.token_version + 1
 WHERE au.id IN (
   SELECT aur.admin_user_id
     FROM admin_user_roles aur
    WHERE aur.role_id = NEW.role_id
 );

-- -----------------------------------------------------------------------------
-- 1b. DELETE 触发器:撤权 → 该角色所有 admin_users.token_version +1
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_arp_ad_bump;
CREATE TRIGGER trg_arp_ad_bump
AFTER DELETE ON admin_role_permissions
FOR EACH ROW
UPDATE admin_users au
   SET au.token_version = au.token_version + 1
 WHERE au.id IN (
   SELECT aur.admin_user_id
     FROM admin_user_roles aur
    WHERE aur.role_id = OLD.role_id
 );

-- -----------------------------------------------------------------------------
-- 2. 兜底 bump:V9/V10/V11 期间受影响账号 (viewer + admin) 立即失效
--    这条 UPDATE 本身就是触发器的"触发样本",会再 bump 一次,但幂等无害
--    (token_version 单调递增即可,具体值不重要)。
-- -----------------------------------------------------------------------------
UPDATE admin_users au
   SET au.token_version = au.token_version + 1
 WHERE au.id IN (
   SELECT DISTINCT aur.admin_user_id
     FROM admin_user_roles aur
     JOIN admin_roles r ON r.id = aur.role_id
    WHERE r.code IN ('viewer', 'admin')
 );

-- 验证:
--   1. SHOW TRIGGERS LIKE 'admin_role_permissions';  应看到 trg_arp_ai_bump / trg_arp_ad_bump
--   2. SELECT role, COUNT(*) FROM admin_users GROUP BY 'affected' — viewer + admin 全员 token_version 至少 +1
--   3. 现有 viewer / admin 账号操作任意受保护接口 → 401「账号状态或权限已变更,请重新登录」
