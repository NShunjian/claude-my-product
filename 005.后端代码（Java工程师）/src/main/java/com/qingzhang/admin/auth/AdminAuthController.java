package com.qingzhang.admin.auth;

import com.qingzhang.admin.dto.AdminMeResponse;
import com.qingzhang.admin.security.AdminPermissionService;
import com.qingzhang.admin.security.AdminPrincipal;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 *   GET /api/admin/auth/me  -> AdminMeResponse
 *
 * 不挂 @RequiresPermission —— AdminAuthInterceptor 已经验证 JWT 有效且有 admin 角色。
 * 加 @RequiresPermission 需要新增 admin:profile:view 权限码,out of scope for v1。
 */
@RestController
@RequestMapping("/api/admin/auth")
public class AdminAuthController {

    private final UserMapper userMapper;
    private final AdminPermissionService permissionService;

    public AdminAuthController(UserMapper userMapper, AdminPermissionService permissionService) {
        this.userMapper = userMapper;
        this.permissionService = permissionService;
    }

    @GetMapping("/me")
    public ApiResponse<AdminMeResponse> me(HttpServletRequest req) {
        Long uid = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (uid == null) {
            throw new BizException(ErrorCode.ADMIN_AUTH_REQUIRED, "未登录");
        }
        User u = userMapper.selectById(uid);
        if (u == null) {
            throw new BizException(ErrorCode.ADMIN_USER_NOT_FOUND, "用户不存在: id=" + uid);
        }
        AdminPrincipal principal = permissionService.resolveForUser(uid);
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
