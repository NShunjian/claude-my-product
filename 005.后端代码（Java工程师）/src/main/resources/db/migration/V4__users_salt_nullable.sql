-- V4: 让 users.salt 可为空。
--
-- 背景:BCrypt 哈希自带 salt($2a$10$<22-char-salt><31-char-hash>),
-- 所以 Java 代码(User 实体 + AuthService)从不读写 salt 列。
-- 但该列定义为 NOT NULL DEFAULT NULL,在 MySQL 严格模式下
-- INSERT 省略该列会报错 "Field 'salt' doesn't have a default value",
-- 导致 POST /api/auth/register 抛出 1500 兜底异常。
--
-- 这是从旧库同步过来的残留列,业务上无意义,放宽为 NULL 即可。
-- 不直接 DROP,保留列以便未来若要做账号迁移 / 审计仍可读到历史标记。

ALTER TABLE users MODIFY salt VARCHAR(64) NULL;