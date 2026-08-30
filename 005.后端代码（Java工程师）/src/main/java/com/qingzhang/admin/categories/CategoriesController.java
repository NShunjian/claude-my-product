package com.qingzhang.admin.categories;

import com.qingzhang.admin.dto.AdminCategoryListItem;
import com.qingzhang.admin.dto.AdminPresetCategoryRequest;
import com.qingzhang.admin.dto.AdminUpdateUserStatusRequest;
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
 *   GET    /api/admin/categories              -> Page<AdminCategoryListItem>
 *   POST   /api/admin/categories              -> AdminCategoryListItem
 *   PATCH  /api/admin/categories/{id}         -> AdminCategoryListItem
 *   DELETE /api/admin/categories/{id}          -> {ok:true}
 *
 * @RequiresPermission 码必须与 V5__admin_rbac_and_audit.sql 的 category:preset:* 字面值完全一致。
 */
@RestController
@RequestMapping("/api/admin/categories")
public class CategoriesController {

    private final AdminCategoryService service;
    private final UserMapper userMapper;  // 仅用于 actor username 查表

    public CategoriesController(AdminCategoryService service, UserMapper userMapper) {
        this.service = service;
        this.userMapper = userMapper;
    }

    @GetMapping
    @RequiresPermission("category:preset:list")
    public ApiResponse<Page<AdminCategoryListItem>> list(@RequestParam(required = false) String type,
                                                         @RequestParam(defaultValue = "1") long page,
                                                         @RequestParam(defaultValue = "20") long size) {
        return ApiResponse.ok(service.list(type, page, size));
    }

    @PostMapping
    @RequiresPermission("category:preset:create")
    public ApiResponse<AdminCategoryListItem> create(HttpServletRequest req,
                                                      @Valid @RequestBody AdminPresetCategoryRequest body) {
        return ApiResponse.ok(service.create(body, actor(req)));
    }

    @PatchMapping("/{id}")
    @RequiresPermission("category:preset:update")
    public ApiResponse<AdminCategoryListItem> update(HttpServletRequest req,
                                                      @PathVariable long id,
                                                      @RequestBody AdminPresetCategoryRequest body) {
        return ApiResponse.ok(service.update(id, body, actor(req)));
    }

    @PatchMapping("/{id}/status")
    @RequiresPermission("category:preset:update")
    public ApiResponse<AdminCategoryListItem> updateStatus(HttpServletRequest req,
                                                            @PathVariable long id,
                                                            @Valid @RequestBody AdminUpdateUserStatusRequest body) {
        return ApiResponse.ok(service.updateStatus(id, body.enabled(), actor(req)));
    }

    @DeleteMapping("/{id}")
    @RequiresPermission("category:preset:delete")
    public ApiResponse<Map<String, Object>> delete(HttpServletRequest req, @PathVariable long id) {
        service.delete(id, actor(req));
        return ApiResponse.ok(Map.of("ok", true));
    }

    private AdminActor actor(HttpServletRequest req) {
        Long uid = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (uid == null) {
            throw new BizException(ErrorCode.ADMIN_AUTH_REQUIRED, "未登录");
        }
        User u = userMapper.selectById(uid);
        String username = u == null ? "unknown" : u.getUsername();
        return new AdminActor(uid, username, req.getRemoteAddr(), req.getHeader("User-Agent"));
    }
}
