package com.qingzhang.admin.users;

import com.qingzhang.admin.dto.AdminGrantRoleRequest;
import com.qingzhang.admin.dto.AdminResetPasswordResponse;
import com.qingzhang.admin.dto.AdminUpdateUserStatusRequest;
import com.qingzhang.admin.dto.AdminUserDetailResponse;
import com.qingzhang.admin.dto.AdminUserListItem;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.admin.security.AdminActor;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 *   GET    /api/admin/users                              -> Page<AdminUserListItem>
 *   GET    /api/admin/users/{id}                         -> AdminUserDetailResponse
 *   PATCH  /api/admin/users/{id}/status                  -> {status}
 *   POST   /api/admin/users/{id}/reset-password          -> AdminResetPasswordResponse
 *   POST   /api/admin/users/{id}/roles                   -> {ok:true}
 *   DELETE /api/admin/users/{id}/roles/{roleCode}        -> {ok:true}
 *
 * AdminAuthInterceptor 已注册到 /api/admin/** (Batch A4);@RequiresPermission 进一步
 * 细化权限码。actor() 帮手方法抽 userId/username/ip/userAgent 给 service 写审计。
 */
@RestController
@RequestMapping("/api/admin/users")
public class UsersController {

    private final AdminUserService service;
    private final UserMapper userMapper;  // 仅用于取 username 填 AdminActor

    public UsersController(AdminUserService service, UserMapper userMapper) {
        this.service = service;
        this.userMapper = userMapper;
    }

    @GetMapping
    @RequiresPermission("user:list")
    public ApiResponse<Page<AdminUserListItem>> list(@RequestParam(required = false) String search,
                                                     @RequestParam(required = false) Byte status,
                                                     @RequestParam(defaultValue = "1") long page,
                                                     @RequestParam(defaultValue = "20") long size) {
        return ApiResponse.ok(service.list(search, status, page, size));
    }

    @GetMapping("/{id}")
    @RequiresPermission("user:detail")
    public ApiResponse<AdminUserDetailResponse> detail(@PathVariable long id) {
        return ApiResponse.ok(service.detail(id));
    }

    @PatchMapping("/{id}/status")
    @RequiresPermission("user:disable")
    public ApiResponse<Map<String, Object>> updateStatus(HttpServletRequest req,
                                                         @PathVariable long id,
                                                         @Valid @RequestBody AdminUpdateUserStatusRequest body) {
        Byte after = service.updateStatus(id, body.enabled(), actor(req));
        return ApiResponse.ok(Map.of("status", after));
    }

    @PostMapping("/{id}/reset-password")
    @RequiresPermission("user:reset_password")
    public ApiResponse<AdminResetPasswordResponse> resetPassword(HttpServletRequest req,
                                                                  @PathVariable long id) {
        return ApiResponse.ok(service.resetPassword(id, actor(req)));
    }

    @PostMapping("/{id}/roles")
    @RequiresPermission("user:grant_role")
    public ApiResponse<Map<String, Object>> grantRole(HttpServletRequest req,
                                                       @PathVariable long id,
                                                       @Valid @RequestBody AdminGrantRoleRequest body) {
        service.grantRole(id, body.roleCode(), actor(req));
        return ApiResponse.ok(Map.of("ok", true));
    }

    @DeleteMapping("/{id}/roles/{roleCode}")
    @RequiresPermission("user:grant_role")
    public ApiResponse<Map<String, Object>> revokeRole(HttpServletRequest req,
                                                        @PathVariable long id,
                                                        @PathVariable String roleCode) {
        service.revokeRole(id, roleCode, actor(req));
        return ApiResponse.ok(Map.of("ok", true));
    }

    private AdminActor actor(HttpServletRequest req) {
        Long uid = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (uid == null) {
            throw new BizException(ErrorCode.ADMIN_AUTH_REQUIRED, "未登录");
        }
        User u = userMapper.selectById(uid);
        String username = u == null ? "unknown" : u.getUsername();
        String ip = req.getRemoteAddr();
        String ua = req.getHeader("User-Agent");
        return new AdminActor(uid, username, ip, ua);
    }
}
