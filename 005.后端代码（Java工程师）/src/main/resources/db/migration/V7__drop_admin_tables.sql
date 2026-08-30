-- =============================================================================
-- V7: 把 6 张 admin 表从 user DB 物理迁出 —— 落到独立 admin DB
--
-- 背景:
--   - V5 + V6 期间,admin_* 6 张表都住在 user DB(qingzhang),与业务表共享 schema
--   - V7 把它们从 user DB 删干净,user DB 只剩业务表
--   - admin DB 的 V1__baseline_admin.sql 同步创建同名 6 张表(以 V6 最终态为模板)
--   - 跨 schema 数据搬运在本迁移的"前置步骤"完成(由 start-admin 脚本跑 JDBC,
--     不在 SQL 里 —— MySQL 不开 FEDERATED 时没法跨 schema INSERT...SELECT)
--
-- 顺序很重要:
--   1. start-admin 先把 user DB admin_* 数据拷到 admin DB
--   2. 然后 Spring boot → Flyway:user DB 跑 V7(本文件),admin DB 跑 V1 baseline
--   3. AdminBootstrapService 启动后 idempotent 创建/补登 super_admin
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 删表顺序: 先删依赖 admin_users / admin_roles / admin_permissions 的子表
DROP TABLE IF EXISTS `admin_audit_logs`;
DROP TABLE IF EXISTS `admin_user_roles`;
DROP TABLE IF EXISTS `admin_role_permissions`;
DROP TABLE IF EXISTS `admin_permissions`;
DROP TABLE IF EXISTS `admin_roles`;
DROP TABLE IF EXISTS `admin_users`;

SET FOREIGN_KEY_CHECKS = 1;
