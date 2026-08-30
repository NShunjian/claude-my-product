package com.qingzhang.admin.users;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.audit.AdminAuditService;
import com.qingzhang.admin.dto.AdminResetPasswordResponse;
import com.qingzhang.admin.dto.AdminUserDetailResponse;
import com.qingzhang.admin.dto.AdminUserListItem;
import com.qingzhang.admin.entity.AdminRole;
import com.qingzhang.admin.entity.AdminUserRole;
import com.qingzhang.admin.mapper.AdminRoleMapper;
import com.qingzhang.admin.mapper.AdminUserRoleMapper;
import com.qingzhang.admin.security.AdminActor;
import com.qingzhang.admin.security.AdminPermissionService;
import com.qingzhang.admin.security.AdminPrincipal;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 用户管理业务 —— 列、详情、改状态、重置密码、授/撤角色。
 * 所有变更通过 AdminAuditService 记录审计日志。
 *
 * ponytail: 不引复杂权限规则 —— "不能禁自己"、"super_admin 不能被授予" 几条硬规则
 * 够用;复杂的"基于角色的操作约束"留 v2。
 */
@Service
public class AdminUserService {

    private static final Logger log = LoggerFactory.getLogger(AdminUserService.class);
    private static final Set<String> PROTECTED_ROLE_CODES = Set.of("super_admin", "admin", "viewer");
    // 排除易混字符:I L O 0 1 —— 生成的密码易读、易输入
    private static final String ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";

    private final UserMapper userMapper;
    private final AdminRoleMapper roleMapper;
    private final AdminUserRoleMapper userRoleMapper;
    private final AdminPermissionService permissionService;
    private final AdminAuditService auditService;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final SecureRandom random = new SecureRandom();

    public AdminUserService(UserMapper userMapper,
                            AdminRoleMapper roleMapper,
                            AdminUserRoleMapper userRoleMapper,
                            AdminPermissionService permissionService,
                            AdminAuditService auditService) {
        this.userMapper = userMapper;
        this.roleMapper = roleMapper;
        this.userRoleMapper = userRoleMapper;
        this.permissionService = permissionService;
        this.auditService = auditService;
    }

    /** 列用户 —— 支持 search (username LIKE)、status 过滤,分页。 */
    public com.qingzhang.admin.dto.Page<AdminUserListItem> list(String search,
                                                                Byte status,
                                                                long page,
                                                                long size) {
        long p = Math.max(1, page);
        long s = Math.min(Math.max(1, size), 100);

        QueryWrapper<User> q = new QueryWrapper<>();
        if (search != null && !search.isBlank()) {
            q.like("username", search.trim());
        }
        if (status != null) {
            q.eq("status", status);
        }
        q.orderByDesc("id");

        IPage<User> mp = userMapper.selectPage(new Page<>(p, s), q);
        long total = mp.getTotal();

        List<AdminUserListItem> items = mp.getRecords().stream().map(u -> new AdminUserListItem(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                u.getStatus(),
                u.getLastLoginAt(),
                u.getCreatedAt(),
                0,  // recordCount —— v1 不预聚合
                0   // bookCount   —— v1 不预聚合
        )).collect(Collectors.toList());

        return new com.qingzhang.admin.dto.Page<>(items, total, s, p);
    }

    /** 详情 —— 用户基本字段 + 当前 admin 角色集合。 */
    public AdminUserDetailResponse detail(long userId) {
        User u = mustUser(userId);
        AdminPrincipal principal = permissionService.resolveForUser(userId);
        return new AdminUserDetailResponse(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                u.getAvatar(),
                u.getGender(),
                u.getAge(),
                u.getEmail(),
                u.getPhone(),
                u.getStatus(),
                u.getLastLoginAt(),
                u.getCreatedAt(),
                principal.roleCodes()
        );
    }

    /** 启用/禁用用户。审计: user.enable / user.disable。 */
    @Transactional(rollbackFor = Exception.class)
    public Byte updateStatus(long userId, boolean enabled, AdminActor actor) {
        User u = mustUser(userId);

        // 不能禁自己
        if (!enabled && u.getId() == actor.userId()) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.disable", "user", userId,
                    "不能禁用自己的账号", actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "不能禁用自己的账号");
        }

        // 不能禁最后一个 super_admin
        if (!enabled && hasRole(userId, "super_admin")) {
            AdminRole superRole = roleMapper.selectOne(
                    new QueryWrapper<AdminRole>().eq("code", "super_admin"));
            if (superRole != null) {
                Long superAdminCount = userRoleMapper.selectCount(
                        new QueryWrapper<AdminUserRole>().eq("role_id", superRole.getId()));
                if (superAdminCount != null && superAdminCount <= 1) {
                    auditService.recordFailure(actor.userId(), actor.username(),
                            "user.disable", "user", userId,
                            "不能禁用最后一个超级管理员", actor.ip(), actor.userAgent());
                    throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "不能禁用最后一个超级管理员");
                }
            }
        }

        Byte before = u.getStatus();
        u.setStatus((byte) (enabled ? 1 : 0));
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);

        String action = enabled ? "user.enable" : "user.disable";
        Map<String, Object> beforeSnap = Map.of("status", before);
        Map<String, Object> afterSnap = Map.of("status", u.getStatus());
        auditService.recordSuccess(actor.userId(), actor.username(),
                action, "user", userId,
                beforeSnap, afterSnap, actor.ip(), actor.userAgent());

        return u.getStatus();
    }

    /** 重置密码 —— 12 位随机密码,BCrypt 入库,返回明文。审计: user.reset_password。 */
    @Transactional(rollbackFor = Exception.class)
    public AdminResetPasswordResponse resetPassword(long userId, AdminActor actor) {
        User u = mustUser(userId);
        String newPassword = generatePassword(12);
        u.setPasswordHash(encoder.encode(newPassword));
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);

        auditService.recordSuccess(actor.userId(), actor.username(),
                "user.reset_password", "user", userId,
                null, Map.of("password_changed", true), actor.ip(), actor.userAgent());
        log.info("[admin] password reset: actor={} target={}", actor.username(), userId);
        return new AdminResetPasswordResponse(newPassword);
    }

    /** 授予 admin 角色。审计: user.grant_role。 */
    @Transactional(rollbackFor = Exception.class)
    public void grantRole(long userId, String roleCode, AdminActor actor) {
        if (roleCode == null || roleCode.isBlank()) {
            throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色 code 不能为空");
        }
        mustUser(userId);
        AdminRole role = roleMapper.selectOne(
                new QueryWrapper<AdminRole>().eq("code", roleCode));
        if (role == null) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.grant_role", "user", userId,
                    "角色不存在: " + roleCode, actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色不存在: " + roleCode);
        }
        // 禁止通过 API 授予 super_admin —— 只能 bootstrap 或 DB
        if ("super_admin".equals(roleCode)) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.grant_role", "user", userId,
                    "不允许通过 API 授予 super_admin", actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "不允许通过 API 授予 super_admin");
        }

        Long existing = userRoleMapper.selectCount(
                new QueryWrapper<AdminUserRole>()
                        .eq("user_id", userId)
                        .eq("role_id", role.getId()));
        if (existing != null && existing > 0) {
            // 已授权 —— idempotent,记 audit 但不报错
            auditService.recordSuccess(actor.userId(), actor.username(),
                    "user.grant_role", "user", userId,
                    Map.of("roles", List.of(roleCode)), Map.of("roles", List.of(roleCode)),
                    actor.ip(), actor.userAgent());
            return;
        }
        AdminUserRole link = new AdminUserRole();
        link.setUserId(userId);
        link.setRoleId(role.getId());
        link.setGrantedAt(Instant.now());
        link.setGrantedBy(actor.userId());
        userRoleMapper.insert(link);

        auditService.recordSuccess(actor.userId(), actor.username(),
                "user.grant_role", "user", userId,
                Map.of("roles", List.of()), Map.of("roles", List.of(roleCode)),
                actor.ip(), actor.userAgent());
    }

    /** 撤销 admin 角色。审计: user.revoke_role。 */
    @Transactional(rollbackFor = Exception.class)
    public void revokeRole(long userId, String roleCode, AdminActor actor) {
        if (roleCode == null || roleCode.isBlank()) {
            throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色 code 不能为空");
        }
        mustUser(userId);
        AdminRole role = roleMapper.selectOne(
                new QueryWrapper<AdminRole>().eq("code", roleCode));
        if (role == null) {
            throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色不存在: " + roleCode);
        }
        // 撤销 super_admin:必须还有别的 super_admin
        if ("super_admin".equals(roleCode)) {
            Long linkCount = userRoleMapper.selectCount(
                    new QueryWrapper<AdminUserRole>().eq("role_id", role.getId()));
            if (linkCount != null && linkCount <= 1) {
                auditService.recordFailure(actor.userId(), actor.username(),
                        "user.revoke_role", "user", userId,
                        "不能撤销最后一个超级管理员", actor.ip(), actor.userAgent());
                throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "不能撤销最后一个超级管理员");
            }
        }
        Long deleted = (long) userRoleMapper.delete(
                new QueryWrapper<AdminUserRole>()
                        .eq("user_id", userId)
                        .eq("role_id", role.getId()));
        if (deleted == 0) {
            // 没授权过 —— 不报错,记 audit
            auditService.recordSuccess(actor.userId(), actor.username(),
                    "user.revoke_role", "user", userId,
                    Map.of("roles", List.of()), Map.of("roles", List.of()),
                    actor.ip(), actor.userAgent());
            return;
        }
        auditService.recordSuccess(actor.userId(), actor.username(),
                "user.revoke_role", "user", userId,
                Map.of("roles", List.of(roleCode)), Map.of("roles", List.of()),
                actor.ip(), actor.userAgent());
    }

    // -------- helpers --------

    private User mustUser(long userId) {
        User u = userMapper.selectById(userId);
        if (u == null) {
            throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "用户不存在: id=" + userId);
        }
        return u;
    }

    private boolean hasRole(long userId, String roleCode) {
        AdminRole role = roleMapper.selectOne(
                new QueryWrapper<AdminRole>().eq("code", roleCode));
        if (role == null) return false;
        Long c = userRoleMapper.selectCount(
                new QueryWrapper<AdminUserRole>()
                        .eq("user_id", userId)
                        .eq("role_id", role.getId()));
        return c != null && c > 0;
    }

    private String generatePassword(int len) {
        StringBuilder sb = new StringBuilder(len);
        for (int i = 0; i < len; i++) {
            sb.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }
}
