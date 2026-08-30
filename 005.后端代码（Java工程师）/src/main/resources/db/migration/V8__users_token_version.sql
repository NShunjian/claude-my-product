-- V8: users.token_version —— 业务用户 JWT 作废机制
--
-- 背景:
--   admin_users 自 V8 (admin token_version) 起有 token_version 列,
--   账号状态/角色变更时 UPDATE 自增,JWT 内 tokenVersion claim 与 DB 不一致即踢出。
--   业务用户 (java-qingzhang.users) 此前无对应机制 —— 管理员禁/启用业务用户后,
--   业务用户 JWT 在过期前一直有效,刷主站不会被踢出。
--
-- 方案 (与 V12 admin token_version 对齐):
--   1. users 加 token_version BIGINT NOT NULL DEFAULT 0
--      —— DEFAULT 0 让所有现存 token (老 token claim 缺失,默认 0) 继续放行,
--         不会一刀切踢出现网用户
--   2. UPDATE users SET token_version = 0 —— 显式置 0,确保 NOT NULL 默认值生效
--   3. AuthService 登录/注册时把 user.token_version 写进 JWT tokenVersion claim
--   4. 新增 UserAuthInterceptor (类似 AdminAuthInterceptor),
--      actorType="user" 时每请求比对 JWT claim vs DB —— 不一致返 401
--   5. BusinessUserService.updateStatus 中禁/启用都 bump token_version,
--      使该用户所有现存 JWT 立即失效
--
-- ponytail:
--   - DEFAULT 0 是过渡兜底:上线瞬间所有 user 仍可用,新登录的 token 把当前
--     DB 值 (0) 写进 claim,后续 bump 才生效
--   - 若想上线立刻踢出现有 user,改成不写 DEFAULT + UPDATE 触发器,但
--     用户体验差;接受老 token 直到自然过期或下一次状态变更

SET NAMES utf8mb4;

ALTER TABLE users
  ADD COLUMN token_version BIGINT NOT NULL DEFAULT 0 COMMENT
    '业务用户 JWT 作废版本:禁/启用 / 密码重置等状态变更自增;JWT 内 tokenVersion 必须等于该字段,否则视为过期。V8 起与 admin_users.token_version 对齐。'
  AFTER status;

-- 显式置 0(对 DEFAULT 兜底;即使 MySQL 没自动填也补一刀)
UPDATE users SET token_version = 0;

-- 验证:
--   SELECT id, username, status, token_version FROM users WHERE id IN (99, 107);
--   应看到 token_version 列全为 0
