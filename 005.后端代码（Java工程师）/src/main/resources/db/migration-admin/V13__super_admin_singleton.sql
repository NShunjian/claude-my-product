-- V13: super_admin 全局唯一 —— 至多 1 个
--
-- 背景:历史遗留导致 admin (id 1000) + alice (id 1003) 都是 super_admin,
--       违反「super_admin 只能有一个」的不变式 (UI 不可见,只能 SQL 制造)。
--
-- 用户决策:保留 alice (1003),admin (1000) 降级为 vice_super_admin
--          (保留高权限,仍可授权/审计);后续任何人不能再制造第二个 super_admin。
--
-- 约束方法 (MySQL 8 不支持 partial unique index):
--   1. 加 super_admin_slot TINYINT NULL 列 (GENERATED 不允许子查询,改用触发器填)
--   2. UPDATE 把现有 super_admin 行 slot 置 1
--   3. UNIQUE INDEX uk_super_admin_singleton —— MySQL 把 NULL 视为互不相等,
--      故「至多 1 行 slot=1,其余 NULL」天然满足「全局至多 1 个 super_admin」
--   4. BEFORE INSERT 触发器:根据 NEW.role_id 是否命中 super_admin 自动 set slot,
--      命中→1(触发 UNIQUE 失败),不命中→NULL(放行)
--   5. 没有 BEFORE UPDATE 触发器 —— admin_user_roles.role_id 在代码里只通过
--      "DELETE 全部 + INSERT 新" 切换,UPDATE 路径不开放
--
-- ponytail: 顺序很关键 —— 必须先 DELETE admin 的 super_admin 行,再加 UNIQUE INDEX,
--          否则当前 2 行 super_admin 会直接 1062 duplicate key。

SET NAMES utf8mb4;

-- 0. 诊断(运行后可注释)
-- SELECT u.id, u.username, r.code
--   FROM admin_users u
--   JOIN admin_user_roles ur ON ur.admin_user_id = u.id
--   JOIN admin_roles r       ON r.id = ur.role_id
--  WHERE r.code = 'super_admin';

-- -----------------------------------------------------------------------------
-- 1. admin (id 1000) 降级:super_admin → vice_super_admin
--    1 角色 1 用户 (V7 不变式):先 DELETE super_admin 行,再 INSERT vice_super_admin 行
-- -----------------------------------------------------------------------------
SET @super_role_id   := (SELECT id FROM admin_roles WHERE code = 'super_admin'       LIMIT 1);
SET @vice_super_id   := (SELECT id FROM admin_roles WHERE code = 'vice_super_admin'  LIMIT 1);

DELETE FROM admin_user_roles
 WHERE admin_user_id = 1000 AND role_id = @super_role_id;

INSERT INTO admin_user_roles (admin_user_id, role_id, granted_at, granted_by)
VALUES (1000, @vice_super_id, NOW(3), 1003)
ON DUPLICATE KEY UPDATE role_id = VALUES(role_id);  -- 兜底:若已存在 vice_super_admin 行就改 role_id

-- 验证:admin (1000) 不再持有 super_admin,改持 vice_super_admin
-- alice (1003) 仍是 super_admin

-- 1.1 admin (1000) 角色变更 → bump token_version,作废旧 JWT
--     V12 触发器只盯 admin_role_permissions,本迁移改的是 admin_user_roles,需手动 bump
UPDATE admin_users SET token_version = token_version + 1 WHERE id = 1000;

-- -----------------------------------------------------------------------------
-- 2. 加 super_admin_slot 列 (TINYINT NULL)
-- -----------------------------------------------------------------------------
ALTER TABLE admin_user_roles
  ADD COLUMN super_admin_slot TINYINT NULL COMMENT
    'super_admin 角色行的 slot=1,其余 NULL;UNIQUE 索引保证全局至多 1 个 super_admin'
  AFTER role_id;

-- -----------------------------------------------------------------------------
-- 3. 把当前 super_admin 行 (alice 1003) slot 置 1
-- -----------------------------------------------------------------------------
UPDATE admin_user_roles SET super_admin_slot = 1 WHERE role_id = @super_role_id;

-- -----------------------------------------------------------------------------
-- 4. UNIQUE 索引 —— MySQL UNIQUE 视 NULL 为互不相等,所以允许多行 NULL
-- -----------------------------------------------------------------------------
ALTER TABLE admin_user_roles
  ADD UNIQUE INDEX uk_super_admin_singleton (super_admin_slot);

-- -----------------------------------------------------------------------------
-- 5. BEFORE INSERT 触发器:自动 set slot
--    - NEW.role_id 命中 super_admin → slot=1 → UNIQUE 索引拒掉 (若已有人持有)
--    - 否则 → slot=NULL → 放行
-- -----------------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_aur_bi_set_super_admin_slot;
CREATE TRIGGER trg_aur_bi_set_super_admin_slot
BEFORE INSERT ON admin_user_roles
FOR EACH ROW
SET NEW.super_admin_slot = (
  SELECT 1 FROM admin_roles
   WHERE code = 'super_admin' AND id = NEW.role_id
   LIMIT 1
);

-- 验证:
--   1. SELECT id, username FROM admin_users WHERE id IN (1000, 1003) — 验证角色行
--   2. SELECT role_id, super_admin_slot FROM admin_user_roles — 应只有 1 行 slot=1
--   3. 试 INSERT 一个新 super_admin 行:应 1062 duplicate key 'uk_super_admin_singleton'
--   4. 试 INSERT 一个 admin 角色行:应成功,slot=NULL