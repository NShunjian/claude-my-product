-- V8: admin_users.token_version —— 用于立刻作废旧 token
--
-- 场景:超管禁用某账号 / 撤销某账号角色后,该账号此前签发的 JWT 仍可访问接口直到自然过期。
-- 解法:每张表加一个 token_version 单调递增字段,签发 JWT 时把当前值塞进 claim;
--      AdminAuthInterceptor 每次请求比对 DB 当前值与 JWT 内值,不一致即拒。
--      任何「账号状态 / 角色」变更都让 token_version + 1,旧 token 立刻失效。
--
-- 该字段为 0 时跳过校验,保留对历史未带 claim 的老 token 的容忍。

ALTER TABLE admin_users
  ADD COLUMN token_version BIGINT NOT NULL DEFAULT 0
  COMMENT '每次账号状态/角色变更自增,用于作废旧 JWT';