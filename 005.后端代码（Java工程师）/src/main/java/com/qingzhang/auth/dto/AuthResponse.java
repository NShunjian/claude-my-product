package com.qingzhang.auth.dto;

import java.util.List;

/**
 * /api/auth/register 与 /api/auth/login 返回:
 *   { "user": {...}, "token": "...",
 *     "permissions": [...], "roleCodes": [...], "isSuperAdmin": false }
 *
 * 前端 src/api/auth.ts 的 AuthResponse 严格对齐此形状。
 * 非管理员用户 permissions/roleCodes 为空数组,isSuperAdmin=false。
 */
public record AuthResponse(UserDTO user,
                           String token,
                           List<String> permissions,
                           List<String> roleCodes,
                           boolean isSuperAdmin) {

    /** 给非管理员注册/无 RBAC 用户用,3 个 RBAC 字段填空值。 */
    public static AuthResponse plain(UserDTO user, String token) {
        return new AuthResponse(user, token, List.of(), List.of(), false);
    }
}
