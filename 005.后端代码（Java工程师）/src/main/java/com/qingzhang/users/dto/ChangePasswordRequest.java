package com.qingzhang.users.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * POST /api/users/me/password 入参。
 */
public record ChangePasswordRequest(
        @NotBlank String oldPassword,
        @NotBlank @Size(min = 6, max = 64) String newPassword
) {}
