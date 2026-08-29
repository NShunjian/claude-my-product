package com.qingzhang.users.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * PATCH /api/users/me 入参。null 字段表示不改(spec §3.3)。
 *
 * 字段全部 nullable,部分更新语义;长度/范围约束走 JSR-380。
 */
public record UpdateProfileRequest(
        @Size(max = 50) String displayName,
        @Size(max = 2_000_000) String avatar,
        @Pattern(regexp = "male|female|other") String gender,
        @Min(0) @Max(120) Integer age
) {}
