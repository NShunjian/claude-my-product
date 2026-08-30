package com.qingzhang.admin.businessusers.dto;

import java.time.Instant;

/**
 * 业务用户列表项 —— 给后台 admin/super_admin 看的精简视图。
 * 字段:用户基础 + 状态 + 最近活跃 + 汇总(账本/流水数 v1 留 0 占位)。
 */
public record BusinessUserListItem(
        long id,
        String uuid,
        String username,
        String displayName,
        String avatar,
        Byte status,
        Instant lastLoginAt,
        Instant createdAt,
        int bookCount,    // v1 不预聚合,前端需要时再开 v2 接口
        int recordCount   // v1 不预聚合
) {
}