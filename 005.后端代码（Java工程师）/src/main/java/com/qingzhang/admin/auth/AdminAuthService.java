package com.qingzhang.admin.auth;

import com.baomidou.dynamic.datasource.annotation.DS;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.qingzhang.admin.entity.AdminUser;
import com.qingzhang.admin.mapper.AdminUserMapper;
import com.qingzhang.admin.security.AdminPermissionService;
import com.qingzhang.admin.security.AdminPrincipal;
import com.qingzhang.auth.JwtUtil;
import com.qingzhang.auth.dto.AuthResponse;
import com.qingzhang.auth.dto.Credentials;
import com.qingzhang.auth.dto.UserDTO;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;

/**
 * Admin 登录 —— 独立于 /api/auth/login(后者走 users 表)。
 *
 * 流程:
 *   1. admin_users 按 username 查
 *   2. 校验 status == 1
 *   3. BCrypt 校验 password
 *   4. lastLoginAt 落库(失败不影响登录)
 *   5. 加载 RBAC 快照 → 塞 JWT claims(actorType=admin_user)
 *   6. 返 AuthResponse —— 形状与 /api/auth/login 一致,前端共用 AuthLoginResponse
 *
 * 错误码:统一走 ErrorCode(1401 = ADMIN_AUTH_REQUIRED),前端不区分"用户不存在/密码错"。
 */
@Service
@DS("admin")
public class AdminAuthService {

    private static final Logger log = LoggerFactory.getLogger(AdminAuthService.class);

    private final AdminUserMapper adminUserMapper;
    private final AdminPermissionService permissionService;
    private final JwtUtil jwtUtil;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public AdminAuthService(AdminUserMapper adminUserMapper,
                            AdminPermissionService permissionService,
                            JwtUtil jwtUtil) {
        this.adminUserMapper = adminUserMapper;
        this.permissionService = permissionService;
        this.jwtUtil = jwtUtil;
    }

    public AuthResponse loginAdmin(Credentials c) {
        AdminUser u = adminUserMapper.selectOne(
                new QueryWrapper<AdminUser>().eq("username", c.username())
        );
        if (u == null || !encoder.matches(c.password(), u.getPasswordHash())) {
            // 不区分"用户不存在"和"密码错" —— 防枚举
            throw new BizException(ErrorCode.ADMIN_AUTH_REQUIRED, "用户名或密码错误");
        }
        if (u.getStatus() == null || u.getStatus() != (byte) 1) {
            throw new BizException(ErrorCode.ADMIN_USER_DISABLED, "账号已禁用");
        }

        try {
            u.setLastLoginAt(Instant.now());
            adminUserMapper.updateById(u);
        } catch (Exception ex) {
            log.warn("[admin-auth] 更新 lastLoginAt 失败: id={} ex={}", u.getId(), ex.getMessage());
        }

        AdminPrincipal principal = permissionService.resolveForAdminUser(u.getId());
        List<String> permissions = principal.permissions();
        List<String> roleCodes = principal.roleCodes();
        boolean isSuperAdmin = principal.isSuperAdmin();

        String token = jwtUtil.issue(u.getId(), permissions, roleCodes, isSuperAdmin, JwtUtil.ACTOR_TYPE_ADMIN);

        return new AuthResponse(toDto(u), token, permissions, roleCodes, isSuperAdmin);
    }

    private UserDTO toDto(AdminUser u) {
        // AuthLoginResponse.user 字段对齐 UserDTO(只取基础 4 字段 + id,admin 不需要 avatar/gender/age)
        return new UserDTO(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                null,   // avatar —— admin 无
                null,   // gender
                null,   // age
                u.getCreatedAt()
        );
    }
}