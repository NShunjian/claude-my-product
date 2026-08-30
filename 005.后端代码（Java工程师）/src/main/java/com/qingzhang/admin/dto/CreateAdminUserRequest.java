package com.qingzhang.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * super_admin 用来建新管理员账号的请求体。
 *
 * 密码后端随机生成(12 位)并通过响应返明文 —— 与 resetPassword 风格一致,
 * 创建者把密码当面/IM 转给新管理员。
 *
 * ponytail:不暴露 "传明文密码" 字段 —— 创建者也不知道初始密码,
 * 强迫走 resetPassword 也能,只是 UX 差一点。
 */
public record CreateAdminUserRequest(
        @NotBlank @Size(min = 3, max = 50)
        @Pattern(regexp = "^[A-Za-z0-9_.-]+$", message = "用户名只能包含字母、数字、_-. ")
        String username,

        @Size(max = 50)
        String displayName,

        // 可选:创建时直接授一个非 super_admin 的角色;空 = 不授任何角色,后续用授权接口
        String roleCode
) {
}