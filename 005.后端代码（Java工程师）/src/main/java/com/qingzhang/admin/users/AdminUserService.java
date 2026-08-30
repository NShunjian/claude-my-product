package com.qingzhang.admin.users;

import com.baomidou.dynamic.datasource.annotation.DS;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.audit.AdminAuditService;
import com.qingzhang.admin.dto.AdminResetPasswordResponse;
import com.qingzhang.admin.dto.AdminUserDetailResponse;
import com.qingzhang.admin.dto.AdminUserListItem;
import com.qingzhang.admin.dto.CreateAdminUserRequest;
import com.qingzhang.admin.dto.CreateAdminUserResponse;
import com.qingzhang.admin.users.dto.BatchDeleteAdminUsersResponse;
import com.qingzhang.admin.entity.AdminRole;
import com.qingzhang.admin.entity.AdminUser;
import com.qingzhang.admin.entity.AdminUserRole;
import com.qingzhang.admin.mapper.AdminRoleMapper;
import com.qingzhang.admin.mapper.AdminUserMapper;
import com.qingzhang.admin.mapper.AdminUserRoleMapper;
import com.qingzhang.admin.security.AdminActor;
import com.qingzhang.admin.security.AdminPermissionService;
import com.qingzhang.admin.security.AdminPrincipal;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 用户管理业务 —— 列、详情、创建、改状态、重置密码、授/撤角色。
 * 所有变更通过 AdminAuditService 记录审计日志。
 *
 * ponytail: 不引复杂权限规则 —— "不能禁自己"、"super_admin 不能被授予" 几条硬规则
 * 够用;复杂的"基于角色的操作约束"留 v2。
 */
@Service
@DS("admin")
public class AdminUserService {

    private static final Logger log = LoggerFactory.getLogger(AdminUserService.class);
    // 排除易混字符:I L O 0 1 —— 生成的密码易读、易输入
    private static final String ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";

    private final AdminUserMapper adminUserMapper;
    private final AdminRoleMapper roleMapper;
    private final AdminUserRoleMapper userRoleMapper;
    private final AdminPermissionService permissionService;
    private final AdminAuditService auditService;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final SecureRandom random = new SecureRandom();

    public AdminUserService(AdminUserMapper adminUserMapper,
                            AdminRoleMapper roleMapper,
                            AdminUserRoleMapper userRoleMapper,
                            AdminPermissionService permissionService,
                            AdminAuditService auditService) {
        this.adminUserMapper = adminUserMapper;
        this.roleMapper = roleMapper;
        this.userRoleMapper = userRoleMapper;
        this.permissionService = permissionService;
        this.auditService = auditService;
    }

    /** 列用户 —— 支持 search (username LIKE)、status 过滤,分页。
     *
     *  actor: 用于决定是否过滤主 super_admin。vice_super_admin 调用时,
     *         自动过滤掉所有持 super_admin 角色的用户(主超管对其隐身)。*/
    public com.qingzhang.admin.dto.Page<AdminUserListItem> list(String search,
                                                                Byte status,
                                                                long page,
                                                                long size,
                                                                AdminActor actor) {
        long p = Math.max(1, page);
        long s = Math.min(Math.max(1, size), 100);

        boolean hideSuperAdmin = actor != null
                && !hasRole(actor.userId(), "super_admin")
                && hasRole(actor.userId(), "vice_super_admin");

        // 1. 取 super_admin 用户 ID 集合(给 vice_super_admin 看时用来排除)
        Set<Long> superAdminIds = hideSuperAdmin ? collectUserIdsByRole("super_admin") : Set.of();

        QueryWrapper<AdminUser> q = new QueryWrapper<>();
        if (search != null && !search.isBlank()) {
            q.like("username", search.trim());
        }
        if (status != null) {
            q.eq("status", status);
        }
        if (!superAdminIds.isEmpty()) {
            q.notIn("id", superAdminIds);
        }
        q.orderByDesc("id");

        IPage<AdminUser> mp = adminUserMapper.selectPage(new Page<>(p, s), q);
        long total = mp.getTotal();

        List<Long> ids = mp.getRecords().stream().map(AdminUser::getId).toList();
        Map<Long, List<String>> rolesByUser = batchLoadRoleCodes(ids);

        List<AdminUserListItem> items = mp.getRecords().stream().map(u -> new AdminUserListItem(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                u.getStatus(),
                u.getLastLoginAt(),
                u.getCreatedAt(),
                0,  // recordCount —— v1 不预聚合
                0,  // bookCount   —— v1 不预聚合
                rolesByUser.getOrDefault(u.getId(), List.of())
        )).collect(Collectors.toList());

        return new com.qingzhang.admin.dto.Page<>(items, total, s, p);
    }

    /** 一次性把当前所有 active role 的 user-id 拿出来 —— 给 list() 做隐藏过滤用。 */
    private Set<Long> collectUserIdsByRole(String roleCode) {
        AdminRole role = roleMapper.selectOne(
                new QueryWrapper<AdminRole>().eq("code", roleCode)
                        .eq("status", 1).isNull("deleted_at"));
        if (role == null) return Set.of();
        List<AdminUserRole> links = userRoleMapper.selectList(
                new QueryWrapper<AdminUserRole>().eq("role_id", role.getId()));
        return links.stream().map(AdminUserRole::getAdminUserId).collect(Collectors.toSet());
    }

    /** 批量拿 user → role codes。一次 user_role 查 + 一次 role 查,避免 N+1。 */
    private Map<Long, List<String>> batchLoadRoleCodes(List<Long> userIds) {
        if (userIds.isEmpty()) return Map.of();
        List<AdminUserRole> links = userRoleMapper.selectList(
                new QueryWrapper<AdminUserRole>().in("admin_user_id", userIds));
        if (links.isEmpty()) return Map.of();

        Set<Long> roleIds = links.stream().map(AdminUserRole::getRoleId).collect(Collectors.toSet());
        Map<Long, String> codeById = roleMapper.selectBatchIds(roleIds).stream()
                .filter(r -> r.getStatus() != null && r.getStatus() == (byte) 1)
                .filter(r -> r.getDeletedAt() == null)
                .collect(Collectors.toMap(AdminRole::getId, AdminRole::getCode));

        Map<Long, List<String>> out = new HashMap<>();
        for (AdminUserRole link : links) {
            String code = codeById.get(link.getRoleId());
            if (code == null) continue;
            out.computeIfAbsent(link.getAdminUserId(), k -> new ArrayList<>()).add(code);
        }
        return out;
    }

    /** 详情 —— 管理员基本字段 + 当前角色集合。avatar/gender/age/email/phone 管理员用不上,固定 null。
     *
     *  vice_super_admin 调用时,如果目标持 super_admin → ADMIN_USER_NOT_FOUND(隐身)。
     *  始终允许 actor 看自己的 detail(包括 super_admin 自己看自己)。*/
    public AdminUserDetailResponse detail(long userId, AdminActor actor) {
        AdminUser u = mustAdminUser(userId);
        // 隐身:仅当「actor 不是自己」且「actor 是 vice_super_admin」且「目标持 super_admin」时拦截
        // 排除自己(super_admin 必能看自己)
        boolean viewerIsViceSuper = actor != null && hasRole(actor.userId(), "vice_super_admin");
        boolean viewerIsSuper = actor != null && hasRole(actor.userId(), "super_admin");
        boolean isSelf = actor != null && actor.userId() == userId;
        if (viewerIsViceSuper && !viewerIsSuper && !isSelf) {
            AdminRole superRole = roleMapper.selectOne(
                    new QueryWrapper<AdminRole>().eq("code", "super_admin"));
            if (superRole != null) {
                Long link = userRoleMapper.selectCount(
                        new QueryWrapper<AdminUserRole>()
                                .eq("admin_user_id", userId)
                                .eq("role_id", superRole.getId()));
                if (link != null && link > 0) {
                    throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "管理员不存在: id=" + userId);
                }
            }
        }
        AdminPrincipal principal = permissionService.resolveForAdminUser(userId);
        return new AdminUserDetailResponse(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                null,  // avatar —— 管理员无头像
                null,  // gender
                null,  // age
                null,  // email
                null,  // phone
                u.getStatus(),
                u.getLastLoginAt(),
                u.getCreatedAt(),
                principal.roleCodes()
        );
    }

    /**
     * 创建新管理员账号(V15 起:super_admin / vice_super_admin 都可调)。
     * - username 唯一校验
     * - 密码后端生成 12 位随机 + BCrypt,明文随响应返回一次(创建者当面转给新管理员)
     * - 可选 roleCode:非空时校验存在 + actor 角色白名单 + 立即授权
     *   actor 是 super_admin      → roleCode ∈ {admin, vice_super_admin, viewer}
     *   actor 是 vice_super_admin → roleCode ∈ {admin, viewer}
     *   (super_admin 仍不能通过 API 创建 —— V7 + V13 双重防线)
     * - 审计 user.create
     */
    @Transactional(rollbackFor = Exception.class)
    public CreateAdminUserResponse create(CreateAdminUserRequest req, AdminActor actor) {
        String username = req.username().trim();

        // 1. username 已存在 → 失败
        AdminUser conflict = adminUserMapper.selectOne(
                new QueryWrapper<AdminUser>().eq("username", username));
        if (conflict != null) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.create", "user", null,
                    "用户名已存在: " + username, actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_USER_CONFLICT, "用户名已存在: " + username);
        }

        Instant now = Instant.now();
        String initialPassword = generatePassword(12);
        AdminUser u = AdminUser.builder()
                .uuid(UUID.randomUUID().toString())
                .username(username)
                .passwordHash(encoder.encode(initialPassword))
                .displayName(req.displayName() == null || req.displayName().isBlank()
                        ? username : req.displayName().trim())
                .status((byte) 1)
                .createdAt(now)
                .updatedAt(now)
                .build();
        adminUserMapper.insert(u);
        long newUserId = u.getId();

        // 2. 可选授权 —— actor 角色决定白名单
        List<String> grantedRoles = List.of();
        if (req.roleCode() != null && !req.roleCode().isBlank()) {
            String roleCode = req.roleCode().trim();

            // V15:按 actor 角色决定可授范围
            boolean actorIsSuper = hasRole(actor.userId(), "super_admin");
            boolean actorIsViceSuper = !actorIsSuper && hasRole(actor.userId(), "vice_super_admin");
            java.util.Set<String> allowed;
            if (actorIsSuper) {
                // 仍禁 super_admin(V7 硬规则)→ 单独短路在前
                if ("super_admin".equals(roleCode)) {
                    auditService.recordFailure(actor.userId(), actor.username(),
                            "user.create", "user", newUserId,
                            "不允许通过 API 创建并授予 super_admin", actor.ip(), actor.userAgent());
                    throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED,
                            "不允许通过 API 创建并授予 super_admin");
                }
                allowed = java.util.Set.of("admin", "vice_super_admin", "viewer");
            } else if (actorIsViceSuper) {
                allowed = java.util.Set.of("admin", "viewer");
            } else {
                // 走到这里说明 @RequiresPermission("user:create") 已被拦截,理论不会到这
                auditService.recordFailure(actor.userId(), actor.username(),
                        "user.create", "user", newUserId,
                        "无 user:create 权限", actor.ip(), actor.userAgent());
                throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED,
                        "无 user:create 权限");
            }
            if (!allowed.contains(roleCode)) {
                auditService.recordFailure(actor.userId(), actor.username(),
                        "user.create", "user", newUserId,
                        "当前角色无权授予 " + roleCode, actor.ip(), actor.userAgent());
                throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED,
                        "当前角色无权授予 " + roleCode + "(允许: " + allowed + ")");
            }

            AdminRole role = roleMapper.selectOne(
                    new QueryWrapper<AdminRole>().eq("code", roleCode));
            if (role == null) {
                auditService.recordFailure(actor.userId(), actor.username(),
                        "user.create", "user", newUserId,
                        "角色不存在: " + roleCode, actor.ip(), actor.userAgent());
                throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色不存在: " + roleCode);
            }
            AdminUserRole link = new AdminUserRole();
            link.setAdminUserId(newUserId);
            link.setRoleId(role.getId());
            link.setGrantedAt(now);
            link.setGrantedBy(actor.userId());
            userRoleMapper.insert(link);
            grantedRoles = List.of(roleCode);
        }

        // 3. 审计 success
        Map<String, Object> afterSnap = new java.util.LinkedHashMap<>();
        afterSnap.put("username", username);
        afterSnap.put("displayName", u.getDisplayName());
        afterSnap.put("status", 1);
        afterSnap.put("roles", grantedRoles);
        auditService.recordSuccess(actor.userId(), actor.username(),
                "user.create", "user", newUserId,
                null, afterSnap, actor.ip(), actor.userAgent());

        log.info("[admin] user created: actor={} newUser={} id={} roles={}",
                actor.username(), username, newUserId, grantedRoles);

        return new CreateAdminUserResponse(newUserId, username, initialPassword);
    }

    /** 启用/禁用管理员。审计: user.enable / user.disable。 */
    @Transactional(rollbackFor = Exception.class)
    public Byte updateStatus(long userId, boolean enabled, AdminActor actor) {
        AdminUser u = mustAdminUser(userId);

        // 有 user:disable 权限的(超管 / 副超管)不能修改自己的账号状态(任何方向:启用/禁用)
        // 这两个角色一旦锁死,登录入口就被封,只剩 DBA 能救 —— 必须从另一超管账户救场
        // 普通 admin / viewer 没有 user:disable 权限,自然不会进到这里
        if (u.getId() == actor.userId()
                && (hasRole(actor.userId(), "super_admin") || hasRole(actor.userId(), "vice_super_admin"))) {
            String action = enabled ? "user.enable" : "user.disable";
            String verb = enabled ? "启用" : "禁用";
            auditService.recordFailure(actor.userId(), actor.username(),
                    action, "user", userId,
                    "不能" + verb + "自己的账号", actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "不能" + verb + "自己的账号");
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
        // 状态变更 → token_version 自增,作废所有现存 JWT
        u.setTokenVersion((u.getTokenVersion() == null ? 0L : u.getTokenVersion()) + 1L);
        adminUserMapper.updateById(u);

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
        AdminUser u = mustAdminUser(userId);
        String newPassword = generatePassword(12);
        long beforeTv = u.getTokenVersion() == null ? 0L : u.getTokenVersion();
        u.setPasswordHash(encoder.encode(newPassword));
        // V8 起:重置密码也 bump token_version —— 旧密码 BCrypt 不再匹配(virtually 立即失效),
        // 同时旧 JWT 立即失效,被重置者所有 session 必须重新登录(用新密码)。
        u.setTokenVersion(beforeTv + 1L);
        u.setUpdatedAt(Instant.now());
        adminUserMapper.updateById(u);

        auditService.recordSuccess(actor.userId(), actor.username(),
                "user.reset_password", "user", userId,
                Map.of("token_version", beforeTv),
                Map.of("password_changed", true, "token_version", u.getTokenVersion()),
                actor.ip(), actor.userAgent());
        log.info("[admin] password reset: actor={} target={} token_version {} → {}",
                actor.username(), userId, beforeTv, u.getTokenVersion());
        return new AdminResetPasswordResponse(newPassword);
    }

    /** 授予 admin 角色。审计: user.grant_role。
     *
     *  V7 后的规则矩阵:
     *    - 每个用户只能有 1 个角色(原角色自动撤销)
     *    - super_admin 不可通过 API 授予(账号由 SQL/迁移维护,不再自动 transfer)
     *    - super_admin 可授 admin / vice_super_admin / viewer
     *    - vice_super_admin 可授 admin / viewer,不能授 super_admin / vice_super_admin
     *    - 其它角色没有 role:grant 权限,前面 @RequiresPermission 拦截
     */
    @Transactional(rollbackFor = Exception.class)
    public void grantRole(long userId, String roleCode, AdminActor actor) {
        if (roleCode == null || roleCode.isBlank()) {
            throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色 code 不能为空");
        }
        mustAdminUser(userId);
        AdminRole role = roleMapper.selectOne(
                new QueryWrapper<AdminRole>().eq("code", roleCode));
        if (role == null) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.grant_role", "user", userId,
                    "角色不存在: " + roleCode, actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色不存在: " + roleCode);
        }

        boolean actorIsSuper = hasRole(actor.userId(), "super_admin");
        boolean actorIsViceSuper = hasRole(actor.userId(), "vice_super_admin");

        // 0. 不能修改自己的角色 —— 与 revokeRole 对称
        if (actor.userId() == userId) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.grant_role", "user", userId,
                    "不能修改自己的角色", actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "不能修改自己的角色");
        }
        // 1. super_admin 不可经 API 授予/转移 — 账号由 SQL/迁移维护,稳定不再变
        if ("super_admin".equals(roleCode)) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.grant_role", "user", userId,
                    "super_admin 不可通过 API 授予", actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED,
                    "super_admin 不可通过 API 授予,请直接联系 DBA 维护");
        }
        // 2. vice_super_admin 只有 super_admin 能授
        if ("vice_super_admin".equals(roleCode) && !actorIsSuper) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.grant_role", "user", userId,
                    "只有超级管理员才能授权 vice_super_admin", actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED,
                    "只有超级管理员才能授权 vice_super_admin");
        }
        // 3. actor 必须有 super 或 vice_super 之一
        if (!actorIsSuper && !actorIsViceSuper) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "user.grant_role", "user", userId,
                    "无权授予角色", actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "无权授予角色");
        }

        // 4. 1-role-per-user:撤销该用户现有的所有角色(同事务)
        List<AdminUserRole> existingLinks = userRoleMapper.selectList(
                new QueryWrapper<AdminUserRole>().eq("admin_user_id", userId));
        // 4.1 角色变更 → token_version 自增,作废所有现存 JWT(权限/角色快照变化)
        AdminUser target = adminUserMapper.selectById(userId);
        if (target != null) {
            target.setTokenVersion((target.getTokenVersion() == null ? 0L : target.getTokenVersion()) + 1L);
            target.setUpdatedAt(Instant.now());
            adminUserMapper.updateById(target);
        }
        List<String> beforeRoles = existingLinks.stream()
                .map((link) -> roleMapper.selectById(link.getRoleId()))
                .filter(java.util.Objects::nonNull)
                .map(AdminRole::getCode)
                .filter(java.util.Objects::nonNull)
                .toList();
        if (!existingLinks.isEmpty()) {
            userRoleMapper.delete(
                    new QueryWrapper<AdminUserRole>().eq("admin_user_id", userId));
        }

        // 5. 授权新角色
        AdminUserRole link = new AdminUserRole();
        link.setAdminUserId(userId);
        link.setRoleId(role.getId());
        link.setGrantedAt(Instant.now());
        link.setGrantedBy(actor.userId());
        userRoleMapper.insert(link);

        auditService.recordSuccess(actor.userId(), actor.username(),
                "user.grant_role", "user", userId,
                Map.of("roles", beforeRoles), Map.of("roles", List.of(roleCode)),
                actor.ip(), actor.userAgent());
        log.info("[admin] role grant: actor={} target={} from={} to={}",
                actor.username(), userId, beforeRoles, roleCode);
    }

    /** 撤销 admin 角色。审计: user.revoke_role。 */
    @Transactional(rollbackFor = Exception.class)
    public void revokeRole(long userId, String roleCode, AdminActor actor) {
        if (roleCode == null || roleCode.isBlank()) {
            throw new BizException(ErrorCode.ADMIN_ROLE_NOT_FOUND, "角色 code 不能为空");
        }
        // V6 split:userId 现指 admin_users.id
        mustAdminUser(userId);
        // 允许自撤角色 —— 撤完后账号变"无角色普通账号",前端会强制登出,下次登录被 ADMIN_AUTH_REQUIRED 拦下
        // 唯一的硬约束仍保留:不能撤销最后一个 super_admin(下面)
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
                        .eq("admin_user_id", userId)
                        .eq("role_id", role.getId()));
        if (deleted > 0) {
            // 角色被实际撤销 → token_version 自增,作废所有现存 JWT
            AdminUser target = adminUserMapper.selectById(userId);
            if (target != null) {
                target.setTokenVersion((target.getTokenVersion() == null ? 0L : target.getTokenVersion()) + 1L);
                target.setUpdatedAt(Instant.now());
                adminUserMapper.updateById(target);
            }
        }
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

    /**
     * 硬删单个管理员账号 —— 不可恢复,绕过 @TableLogic。
     *
     * 销毁链(2 张表):
     *   1. admin_users  —— 物理删除该行
     *   2. admin_user_roles —— FK CASCADE 自动清(不需要显式)
     *
     * admin_audit_logs 不动 —— 审计历史是合规资产,actor username 已 denormalize 进日志行,
     * 即使用户被硬删,日志里仍能看到「alice 在 YYYY-MM-DD 做过什么」。
     *
     * 双重护栏(同软删版本):
     *   - 不能删自己
     *   - 不能删最后一个 super_admin
     *
     * audit action: admin_user.hard_delete
     */
    @Transactional(rollbackFor = Exception.class)
    public void delete(long userId, AdminActor actor) {
        if (adminUserMapper.existsLive(userId) == 0) {
            throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "管理员不存在或已被删除: id=" + userId);
        }

        // 0. 不能删自己
        if (userId == actor.userId()) {
            auditService.recordFailure(actor.userId(), actor.username(),
                    "admin_user.hard_delete", "admin_user", userId,
                    "不能删除自己的账号", actor.ip(), actor.userAgent());
            throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "不能删除自己的账号");
        }
        // 1. 不能删最后一个 super_admin
        if (hasRole(userId, "super_admin")) {
            AdminRole superRole = roleMapper.selectOne(
                    new QueryWrapper<AdminRole>().eq("code", "super_admin"));
            if (superRole != null) {
                Long superAdminCount = userRoleMapper.selectCount(
                        new QueryWrapper<AdminUserRole>().eq("role_id", superRole.getId()));
                if (superAdminCount != null && superAdminCount <= 1) {
                    auditService.recordFailure(actor.userId(), actor.username(),
                            "admin_user.hard_delete", "admin_user", userId,
                            "不能删除最后一个超级管理员", actor.ip(), actor.userAgent());
                    throw new BizException(ErrorCode.ADMIN_PERMISSION_DENIED, "不能删除最后一个超级管理员");
                }
            }
        }

        // 2. 取 username 用于审计快照(硬删后 username 也得留下)
        AdminUser u = adminUserMapper.selectById(userId);
        String beforeUsername = u == null ? "?" : u.getUsername();
        Byte beforeStatus = u == null ? null : u.getStatus();

        // 3. 真 DELETE FROM —— admin_user_roles 由 FK CASCADE 自动清
        int affected = adminUserMapper.hardDeleteById(userId);
        if (affected == 0) {
            throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "管理员不存在: id=" + userId);
        }

        auditService.recordSuccess(actor.userId(), actor.username(),
                "admin_user.hard_delete", "admin_user", userId,
                Map.of("username", beforeUsername, "status", beforeStatus),
                Map.of("username", beforeUsername, "deleted", true),
                actor.ip(), actor.userAgent());
        log.info("[admin] admin user hard deleted: actor={} target={} username={}",
                actor.username(), userId, beforeUsername);
    }

    /**
     * 批量硬删管理员账号 —— 不可恢复。
     *
     * 校验 + skipped 语义同业务用户批量硬删。
     * audit: admin_user.batch_hard_delete
     */
    @Transactional(rollbackFor = Exception.class)
    public BatchDeleteAdminUsersResponse batchDelete(List<Long> ids, AdminActor actor) {
        if (ids == null || ids.isEmpty()) {
            throw new BizException(ErrorCode.VALIDATION_FAILED, "请选择至少一个账号");
        }
        if (ids.size() > 100) {
            throw new BizException(ErrorCode.VALIDATION_FAILED,
                    "单次最多删除 100 个账号,当前选了 " + ids.size() + " 个");
        }

        List<Long> cleanIds = ids.stream()
                .filter(id -> id != null && id > 0)
                .distinct()
                .toList();
        if (cleanIds.isEmpty()) {
            return new BatchDeleteAdminUsersResponse(0, ids.size());
        }

        // super_admin 角色 id 一次性查出
        AdminRole superRole = roleMapper.selectOne(
                new QueryWrapper<AdminRole>().eq("code", "super_admin"));
        Long superRoleId = superRole == null ? null : superRole.getId();

        int deleted = 0;
        int skipped = 0;
        for (Long id : cleanIds) {
            if (adminUserMapper.existsLive(id) == 0) {
                skipped++;
                continue;
            }
            // 不能删自己
            if (id == actor.userId()) {
                skipped++;
                continue;
            }
            // 不能删最后一个 super_admin
            if (superRoleId != null && hasRole(id, "super_admin")) {
                Long superCount = userRoleMapper.selectCount(
                        new QueryWrapper<AdminUserRole>().eq("role_id", superRoleId));
                if (superCount != null && superCount <= 1) {
                    skipped++;
                    continue;
                }
            }
            int affected = adminUserMapper.hardDeleteById(id);
            if (affected > 0) deleted++; else skipped++;
        }

        auditService.recordSuccess(actor.userId(), actor.username(),
                "admin_user.batch_hard_delete", "admin_user", null,
                Map.of("ids", ids),
                Map.of("deleted", deleted, "skipped", skipped),
                actor.ip(), actor.userAgent());
        log.info("[admin] admin user batch hard delete: actor={} requested={} deleted={} skipped={}",
                actor.username(), ids.size(), deleted, skipped);
        return new BatchDeleteAdminUsersResponse(deleted, skipped);
    }

    // -------- helpers --------

    /** V6 split:所有 userId 语义指向 admin_users.id(从 1000 起)。 */
    private AdminUser mustAdminUser(long adminUserId) {
        AdminUser u = adminUserMapper.selectById(adminUserId);
        if (u == null) {
            throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "管理员不存在: id=" + adminUserId);
        }
        return u;
    }

    private boolean hasRole(long userId, String roleCode) {
        AdminRole role = roleMapper.selectOne(
                new QueryWrapper<AdminRole>().eq("code", roleCode));
        if (role == null) return false;
        Long c = userRoleMapper.selectCount(
                new QueryWrapper<AdminUserRole>()
                        .eq("admin_user_id", userId)
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