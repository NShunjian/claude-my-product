package com.qingzhang.admin.security;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.qingzhang.admin.entity.AdminPermission;
import com.qingzhang.admin.entity.AdminRole;
import com.qingzhang.admin.entity.AdminRolePermission;
import com.qingzhang.admin.entity.AdminUserRole;
import com.qingzhang.admin.mapper.AdminPermissionMapper;
import com.qingzhang.admin.mapper.AdminRoleMapper;
import com.qingzhang.admin.mapper.AdminRolePermissionMapper;
import com.qingzhang.admin.mapper.AdminUserRoleMapper;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 加载一个 admin_users 的权限快照 —— 给 AdminAuthService (登录时塞 JWT claims)、
 * /api/admin/auth/me、未来 "admin 改角色后立即生效" 场景。
 *
 * V6 split 后:操作对象是 admin_users.id(从 1000 起),不再接触 users 表。
 * 快速路径:无 admin 角色绑定时,1 次 user-role 查询后 early-return。
 */
@Service
public class AdminPermissionService {

    private final AdminRoleMapper roleMapper;
    private final AdminUserRoleMapper userRoleMapper;
    private final AdminRolePermissionMapper rolePermissionMapper;
    private final AdminPermissionMapper permissionMapper;

    public AdminPermissionService(AdminRoleMapper roleMapper,
                                 AdminUserRoleMapper userRoleMapper,
                                 AdminRolePermissionMapper rolePermissionMapper,
                                 AdminPermissionMapper permissionMapper) {
        this.roleMapper = roleMapper;
        this.userRoleMapper = userRoleMapper;
        this.rolePermissionMapper = rolePermissionMapper;
        this.permissionMapper = permissionMapper;
    }

    /** 该 admin 账号当前有效的 admin 权限快照。无 admin 角色时返回空 principal。 */
    public AdminPrincipal resolveForAdminUser(long adminUserId) {
        List<AdminUserRole> links = userRoleMapper.selectList(
                new QueryWrapper<AdminUserRole>().eq("admin_user_id", adminUserId));
        if (links.isEmpty()) {
            return new AdminPrincipal(adminUserId, List.of(), List.of(), false);
        }

        List<Long> roleIds = links.stream().map(AdminUserRole::getRoleId).toList();
        List<AdminRole> roles = roleMapper.selectBatchIds(roleIds).stream()
                .filter(r -> r.getStatus() != null && r.getStatus() == (byte) 1)
                .filter(r -> r.getDeletedAt() == null)
                .toList();
        if (roles.isEmpty()) {
            return new AdminPrincipal(adminUserId, List.of(), List.of(), false);
        }

        List<String> roleCodes = roles.stream().map(AdminRole::getCode).toList();
        boolean isSuperAdmin = roleCodes.contains("super_admin");

        List<Long> activeRoleIds = roles.stream().map(AdminRole::getId).toList();
        List<AdminRolePermission> rpList = new ArrayList<>();
        for (Long rid : activeRoleIds) {
            rpList.addAll(rolePermissionMapper.selectList(
                    new QueryWrapper<AdminRolePermission>().eq("role_id", rid)));
        }
        Set<Long> permIds = rpList.stream()
                .map(AdminRolePermission::getPermissionId)
                .collect(Collectors.toCollection(HashSet::new));
        if (permIds.isEmpty()) {
            return new AdminPrincipal(adminUserId, roleCodes, List.of(), isSuperAdmin);
        }
        List<String> permissions = permissionMapper.selectBatchIds(permIds).stream()
                .map(AdminPermission::getCode)
                .sorted()
                .collect(Collectors.toList());

        return new AdminPrincipal(adminUserId, roleCodes, permissions, isSuperAdmin);
    }
}