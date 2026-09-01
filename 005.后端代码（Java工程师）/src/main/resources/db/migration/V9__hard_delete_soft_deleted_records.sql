-- 物理清理 records 表里 deleted_at IS NOT NULL 的所有行。
-- 背景:2026-09-01 把 Record 实体的 deletedAt 字段移除后,前端调 DELETE /api/records/{uuid}
--      已走真 DELETE,但切换前累计的软删除行(只置了 deleted_at,从未被 row)仍占着表。
--      按用户决定(2026-09-01 「真正删除」),一次性把这些遗留软删除行物理清掉。
-- 影响范围:仅 records 表,无 FK 指向 records,删除安全。
-- 不可逆:运行后无法恢复。如需审计,执行前先 SELECT * FROM records WHERE deleted_at IS NOT NULL 备份。

DELETE FROM records WHERE deleted_at IS NOT NULL;