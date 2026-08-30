package com.qingzhang.admin.security;

import java.util.List;

/**
 * AdminPermissionService.resolveForAdminUser 的返回值。
 * 描述一个 admin_users 行当前的 RBAC 快照。
 *
 * V6 split 后:adminUserId 是 admin_users.id(从 1000 起),不再与 users.id 共享值域。
 */
public record AdminPrincipal(
        long adminUserId,
        List<String> roleCodes,
        List<String> permissions,
        boolean isSuperAdmin
) {}