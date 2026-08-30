-- V5: 占位迁移 —— 历史 no-op
--
-- 初版尝试给 vice_super_admin 加 user:grant_role / user:revoke_role,
-- 但 V1 baseline 并没有这两个 code —— V1 用的命名是 role:grant / role:revoke,
-- controller 也跟着写错了 user:grant_role(语义上根本不该叫这个)。
--
-- 修复路线(已采纳):controller @RequiresPermission 直接改成
--   POST   /{id}/roles        → role:grant
--   DELETE /{id}/roles/{code} → role:revoke
--   GET    /{id}              → user:view(V1 已有)
-- 不新增 permission code,V1 baseline 不变。
--
-- 此文件保留:flyway 已记录 V5 applied,删它会校验失败。
-- 内容改写为"占位"注释,让历史可追溯。

SELECT 1;
