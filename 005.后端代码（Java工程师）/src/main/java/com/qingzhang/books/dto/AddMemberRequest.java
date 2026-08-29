package com.qingzhang.books.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

/**
 * POST /api/books/{uuid}/members 入参:按用户名邀请。
 */
public record AddMemberRequest(
        @NotBlank String username,
        @NotBlank @Pattern(regexp = "admin|editor|viewer") String role
) {}
