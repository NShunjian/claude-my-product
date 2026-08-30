package com.qingzhang.admin.dto;
import java.time.Instant;
import java.util.List;
public record AdminUserDetailResponse(
    long id, String uuid, String username, String displayName,
    String avatar, String gender, Integer age, String email, String phone,
    Byte status, Instant lastLoginAt, Instant createdAt,
    List<String> roles
) {}
