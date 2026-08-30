package com.qingzhang.admin.security;

import java.util.List;

/**
 * AdminPermissionService.resolveForUser 的返回值。
 * 描述一个用户当前的 admin 权限快照。
 */
public record AdminPrincipal(
        long userId,
        List<String> roleCodes,
        List<String> permissions,
        boolean isSuperAdmin
) {}
