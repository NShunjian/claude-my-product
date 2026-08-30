-- V17: 把 business_user:delete 绑给 super_admin / vice_super_admin
--
-- 背景:
--   V16 引入 business_user:delete 时,只在 admin_role_permissions 里绑了 admin 角色。
--   V16 文件里注释错误地写"super_admin / vice_super_admin 由 V1 baseline 跨连
--   自动覆盖" —— V1 的跨连只跑一次,新增的权限不会自动落给这两个角色。
--   结果:用 super_admin 账号登录看不到批量删除的 checkbox 列(前端按权限渲染)。
--
-- 修法:不动 V16(Flyway 已记录 checksum,改它下一次启动校验失败),
--       新增 V17 显式把已存在的 business_user:delete 绑给 super_admin / vice_super_admin。
--       NOT EXISTS 兜底,幂等,跑过也不会重复绑定。
--
-- 受影响的现场:
--   - 当前 DB:admin 已有此权限,super_admin / vice_super_admin 没有
--   - 当前用户的 super_admin JWT 里不带此权限 → 需重新登录才能看到 UI 入口
--
-- 后续新增权限的约定(写在这里给后续人看):
--   1. 新增权限的迁移里,必须显式 NOT EXISTS 给 super_admin + vice_super_admin + admin 各 INSERT 一次
--   2. 不要依赖"V1 baseline 跨连" —— 那是 V1 启动时一次性快照,后续新增权限收不到

SET NAMES utf8mb4;

-- 把 business_user:delete 绑给 super_admin
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'super_admin'
     AND p.`code` = 'business_user:delete'
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.role_id       = r.id
          AND arp2.permission_id = p.id
     );

-- 把 business_user:delete 绑给 vice_super_admin
INSERT INTO `admin_role_permissions` (`role_id`, `permission_id`)
  SELECT r.id, p.id
    FROM `admin_roles` r, `admin_permissions` p
   WHERE r.`code` = 'vice_super_admin'
     AND p.`code` = 'business_user:delete'
     AND NOT EXISTS (
       SELECT 1 FROM `admin_role_permissions` arp2
        WHERE arp2.role_id       = r.id
          AND arp2.permission_id = p.id
     );

-- 验证:
--   super_admin / vice_super_admin / admin 都有 business_user:delete
--   viewer 没有