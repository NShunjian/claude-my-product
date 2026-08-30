package com.qingzhang.admin.businessusers;

import com.qingzhang.admin.businessusers.dto.BatchDeleteBusinessUsersRequest;
import com.qingzhang.admin.businessusers.dto.BatchDeleteBusinessUsersResponse;
import com.qingzhang.admin.businessusers.dto.BusinessUserDetailResponse;
import com.qingzhang.admin.businessusers.dto.BusinessUserListItem;
import com.qingzhang.admin.dto.AdminResetPasswordResponse;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.admin.security.AdminActorResolver;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.common.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
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
 *   GET    /api/admin/business-users                       -> Page<BusinessUserListItem>
 *   GET    /api/admin/business-users/{id}                  -> BusinessUserDetailResponse
 *   GET    /api/admin/business-users/{id}/hard-delete-preview -> HardDeletePreview(预览销毁规模)
 *   PATCH  /api/admin/business-users/{id}/status           -> {status}
 *   POST   /api/admin/business-users/{id}/reset-password   -> AdminResetPasswordResponse
 *   DELETE /api/admin/business-users/{id}                  -> BatchDeleteBusinessUsersResponse(单硬删)
 *   POST   /api/admin/business-users/batch-delete          -> BatchDeleteBusinessUsersResponse(批量硬删)
 *
 * 与 UsersController (管 admin 账号) 平级,但目标对象是 java-qingzhang.users。
 *
 * 跨库:controller 不挂 @DS,默认走 master DB;actor() 通过 AdminActorResolver
 * (独立的 @DS("admin") bean)切到 admin 库取 username。
 *
 * 权限边界:
 *   - super_admin + admin 都能调(都有 business_user:*)
 *   - viewer 没有 business_user:*,自动 1403
 */
@RestController("adminBusinessUsersController")
@RequestMapping("/api/admin/business-users")
public class BusinessUsersController {

    private final BusinessUserService service;
    private final AdminActorResolver actorResolver;

    public BusinessUsersController(BusinessUserService service, AdminActorResolver actorResolver) {
        this.service = service;
        this.actorResolver = actorResolver;
    }

    @GetMapping
    @RequiresPermission("business_user:list")
    public ApiResponse<Page<BusinessUserListItem>> list(@RequestParam(required = false) String search,
                                                        @RequestParam(required = false) Byte status,
                                                        @RequestParam(defaultValue = "1") long page,
                                                        @RequestParam(defaultValue = "20") long size) {
        return ApiResponse.ok(service.list(search, status, page, size));
    }

    @GetMapping("/{id}")
    @RequiresPermission("business_user:view")
    public ApiResponse<BusinessUserDetailResponse> detail(@PathVariable long id) {
        return ApiResponse.ok(service.detail(id));
    }

    @PatchMapping("/{id}/status")
    @RequiresPermission("business_user:disable")
    public ApiResponse<Map<String, Object>> updateStatus(HttpServletRequest req,
                                                         @PathVariable long id,
                                                         @RequestParam boolean enabled) {
        Byte after = service.updateStatus(id, enabled, actorResolver.resolve(req));
        return ApiResponse.ok(Map.of("status", after));
    }

    @PostMapping("/{id}/reset-password")
    @RequiresPermission("business_user:reset_password")
    public ApiResponse<AdminResetPasswordResponse> resetPassword(HttpServletRequest req,
                                                                  @PathVariable long id) {
        return ApiResponse.ok(service.resetPassword(id, actorResolver.resolve(req)));
    }

    /**
     * 预览硬删某用户的销毁规模 —— 前端 confirm dialog 文案。
     *   不可逆操作的「最后一道防线」:把账本/流水/账户/分类的真实计数告诉操作员,
     *   避免「我以为只是删个用户,没想到连带 5000 条流水一起没了」。
     */
    @GetMapping("/{id}/hard-delete-preview")
    @RequiresPermission("business_user:delete")
    public ApiResponse<BusinessUserService.HardDeletePreview> hardDeletePreview(@PathVariable long id) {
        return ApiResponse.ok(service.preview(id));
    }

    /** 单硬删 —— 不可恢复。响应里带回各表实际销毁的行数。 */
    @DeleteMapping("/{id}")
    @RequiresPermission("business_user:delete")
    public ApiResponse<BatchDeleteBusinessUsersResponse> delete(HttpServletRequest req,
                                                                 @PathVariable long id) {
        return ApiResponse.ok(service.delete(id, actorResolver.resolve(req)));
    }

    /** 批量硬删 —— 不可恢复。body: { ids: number[] },上限 100。 */
    @PostMapping("/batch-delete")
    @RequiresPermission("business_user:delete")
    public ApiResponse<BatchDeleteBusinessUsersResponse> batchDelete(HttpServletRequest req,
                                                                     @RequestBody BatchDeleteBusinessUsersRequest body) {
        return ApiResponse.ok(service.batchDelete(body.ids(), actorResolver.resolve(req)));
    }
}