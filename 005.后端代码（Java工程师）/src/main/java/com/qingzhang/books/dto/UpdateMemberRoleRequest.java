package com.qingzhang.books.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * PATCH /api/books/{uuid}/members/{userUuid} 入参:改角色。
 * 注:不允许把 owner 改成别的角色(避免无主),也不允许从 owner 升上来(spec §5.3)。
 */
public record UpdateMemberRoleRequest(
        @NotBlank @Pattern(regexp = "admin|editor|viewer") String role
) {}
