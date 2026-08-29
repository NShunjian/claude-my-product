package com.qingzhang.auth.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;

/**
 * 与前端 src/auth/AuthContext.tsx 期望的 User 形状严格对齐:
 *   { id, uuid, username, displayName, avatar, gender, age, createdAt }
 * 字段缺失以前端为准;@JsonInclude.NON_NULL 让可空字段不出现。
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record UserDTO(
        Long id,
        String uuid,
        String username,
        String displayName,
        String avatar,
        String gender,
        Integer age,
        Instant createdAt
) {}
