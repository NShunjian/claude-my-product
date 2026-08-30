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
 * 加载一个用户的 admin 权限快照 —— 给 AuthService (登录时塞 JWT claims)、
 * 未来 "用户改角色后立即生效" 场景、以及管理后台刷新 me 用。
 *
 * ponytail: 复用 Batch A2 的 4 个 mapper;admin 权限查询在 admin 子模块内自包含,
 * 不再借 users/UserMapper。常规用户 (无 admin 角色) 走快速路径:1 次 user-role
 * 查询后 early-return —— 绝大多数请求不会到 admin 这边,这是热路径。
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

    /** 该用户当前有效的 admin 权限快照。无 admin 角色时返回空 principal。 */
    public AdminPrincipal resolveForUser(long userId) {
        List<AdminUserRole> links = userRoleMapper.selectList(
                new QueryWrapper<AdminUserRole>().eq("user_id", userId));
        if (links.isEmpty()) {
            return new AdminPrincipal(userId, List.of(), List.of(), false);
        }

        List<Long> roleIds = links.stream().map(AdminUserRole::getRoleId).toList();
        List<AdminRole> roles = roleMapper.selectBatchIds(roleIds).stream()
                .filter(r -> r.getStatus() != null && r.getStatus() == (byte) 1)
                .filter(r -> r.getDeletedAt() == null)
                .toList();
        if (roles.isEmpty()) {
            return new AdminPrincipal(userId, List.of(), List.of(), false);
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
            return new AdminPrincipal(userId, roleCodes, List.of(), isSuperAdmin);
        }
        List<String> permissions = permissionMapper.selectBatchIds(permIds).stream()
                .map(AdminPermission::getCode)
                .sorted()
                .collect(Collectors.toList());

        return new AdminPrincipal(userId, roleCodes, permissions, isSuperAdmin);
    }
}
