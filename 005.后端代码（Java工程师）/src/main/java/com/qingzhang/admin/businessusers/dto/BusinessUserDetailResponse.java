package com.qingzhang.admin.businessusers.dto;

import java.time.Instant;

/**
 * 业务用户详情 —— 给后台 admin/super_admin 看的完整视图。
 * 包含 profile + 状态 + 最近活跃。不返密码哈希。
 */
public record BusinessUserDetailResponse(
        long id,
        String uuid,
        String username,
        String displayName,
        String avatar,
        String gender,
        Integer age,
        String email,
        String phone,
        Byte status,
        Instant lastLoginAt,
        String lastLoginIp,
        Instant createdAt,
        Instant updatedAt
) {
}