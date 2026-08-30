package com.qingzhang.admin.auth;

import com.qingzhang.admin.dto.AdminMeResponse;
import com.qingzhang.admin.entity.AdminUser;
import com.qingzhang.admin.mapper.AdminUserMapper;
import com.qingzhang.admin.security.AdminPermissionService;
import com.qingzhang.admin.security.AdminPrincipal;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.auth.JwtUtil;
import com.qingzhang.auth.dto.AuthResponse;
import com.qingzhang.auth.dto.Credentials;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 *   POST /api/admin/auth/login    {username,password} -> AuthResponse(带 admin RBAC claims)
 *   GET  /api/admin/auth/me       Authorization: Bearer .. -> AdminMeResponse
 *
 * /login 不挂 interceptor(见 AdminInterceptorConfig.excludePathPatterns)——
 * 自己签发 token,不需要前置鉴权。
 * /me 由 AdminAuthInterceptor 守门:必须有 admin 角色。
 */
@RestController("adminAuthController")
@RequestMapping("/api/admin/auth")
public class AdminAuthController {

    private final AdminAuthService adminAuthService;
    private final AdminUserMapper adminUserMapper;
    private final AdminPermissionService permissionService;

    public AdminAuthController(AdminAuthService adminAuthService,
                               AdminUserMapper adminUserMapper,
                               AdminPermissionService permissionService) {
        this.adminAuthService = adminAuthService;
        this.adminUserMapper = adminUserMapper;
        this.permissionService = permissionService;
    }

    @PostMapping("/login")
    public ApiResponse<AuthResponse> login(@Valid @RequestBody Credentials body) {
        return ApiResponse.ok(adminAuthService.loginAdmin(body));
    }

    @GetMapping("/me")
    public ApiResponse<AdminMeResponse> me(HttpServletRequest req) {
        Long uid = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (uid == null) {
            throw new BizException(ErrorCode.ADMIN_AUTH_REQUIRED, "未登录");
        }
        // V6 split:uid 现在是 admin_users.id(从 1000 起),不再查 users 表
        AdminUser u = adminUserMapper.selectById(uid);
        if (u == null) {
            throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "管理员不存在: id=" + uid);
        }
        AdminPrincipal principal = permissionService.resolveForAdminUser(uid);
        return ApiResponse.ok(new AdminMeResponse(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                principal.isSuperAdmin(),
                principal.permissions(),
                principal.roleCodes()
        ));
    }
}