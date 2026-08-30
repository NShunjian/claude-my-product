-- V7: 删除 vice_admin 角色 + 多角色去重
--
-- 用户最新决策:
--   1. 副管理员 (vice_admin) 角色取消,只保留 super_admin / vice_super_admin / admin
--   2. 每个用户只能有 1 个角色(原来允许多角色堆叠,UI 上多徽章乱)
--   3. 账号不再变化 — super_admin 不再通过 API 转移,需直连 DB 维护
--
-- 本迁移:
--   a. 去重:每个用户只保留"权限最大的"那个角色,删除其它 user_role 行
--      优先级 super_admin > vice_super_admin > admin > viewer
--   b. 删 vice_admin 角色的所有 user_role / role_permission 关联
--   c. 删 vice_admin 角色行本身
--
-- ponytail:用 user_id + role_code 关联删,避免硬编码 role_id。
--          MySQL 不允许在 DELETE/UPDATE 的 WHERE 里直接子查询同一张表,
--          故 EXISTS 里的 SELECT 套一层 DERIVED 把它隔离出去。

SET NAMES utf8mb4;

-- 1. 诊断(运行后可注释)
-- SELECT ur.admin_user_id, u.username, r.code FROM admin_user_roles ur
--   JOIN admin_users u ON u.id = ur.admin_user_id
--   JOIN admin_roles r ON r.id = ur.role_id
--  ORDER BY ur.admin_user_id, FIELD(r.code,'super_admin','vice_super_admin','admin','viewer');

-- 2. 去重:对每个用户,保留优先级最高的角色,删其它
-- 优先级 super_admin=1 (highest) > vice_super_admin=2 > admin=3 > viewer=4
DELETE ur FROM admin_user_roles ur
  JOIN admin_roles r ON r.id = ur.role_id
 WHERE EXISTS (
   SELECT 1 FROM (
     SELECT ur2.admin_user_id AS uid, r2.code AS code
       FROM admin_user_roles ur2
       JOIN admin_roles r2 ON r2.id = ur2.role_id
   ) AS sub
   WHERE sub.uid = ur.admin_user_id
     AND FIELD(sub.code, 'super_admin','vice_super_admin','admin','viewer')
         < FIELD(r.code,   'super_admin','vice_super_admin','admin','viewer')
 );

-- 3. 删 vice_admin 角色的所有 user_role 行
DELETE ur FROM admin_user_roles ur
  JOIN admin_roles r ON r.id = ur.role_id
 WHERE r.code = 'vice_admin';

-- 4. 删 vice_admin 角色的所有 role_permission 行
DELETE arp FROM admin_role_permissions arp
  JOIN admin_roles r ON r.id = arp.role_id
 WHERE r.code = 'vice_admin';

-- 5. 删 vice_admin 角色本身
DELETE FROM admin_roles WHERE code = 'vice_admin';

-- 验证:
-- 每个用户应只剩 1 个角色(alice → super_admin;vicesuper → vice_super_admin;bizadmin → admin;viceadmin 失去角色变空)
-- admin_roles 表里没有 vice_admin
