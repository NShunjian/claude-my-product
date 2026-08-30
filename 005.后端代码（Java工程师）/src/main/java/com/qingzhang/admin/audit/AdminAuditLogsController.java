package com.qingzhang.admin.audit;

import com.qingzhang.admin.dto.AdminAuditLogDetailResponse;
import com.qingzhang.admin.dto.AdminAuditLogListItem;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.common.ApiResponse;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;

/**
 *   GET  /api/admin/audit-logs        -> Page<AdminAuditLogListItem>  (audit:list)
 *   GET  /api/admin/audit-logs/{uuid} -> AdminAuditLogDetailResponse  (audit:list)
 *
 * audit:list 仅 super_admin 持有 (V5 seed);admin/viewer 角色拒绝。
 */
@RestController
@RequestMapping("/api/admin/audit-logs")
public class AdminAuditLogsController {

    private final AdminAuditLogsService service;

    public AdminAuditLogsController(AdminAuditLogsService service) {
        this.service = service;
    }

    @GetMapping
    @RequiresPermission("audit:list")
    public ApiResponse<Page<AdminAuditLogListItem>> list(@RequestParam(required = false) String actorUsername,
                                                          @RequestParam(required = false) String action,
                                                          @RequestParam(required = false) String targetType,
                                                          @RequestParam(required = false) Long targetId,
                                                          @RequestParam(required = false) String result,
                                                          @RequestParam(required = false)
                                                          @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant dateFrom,
                                                          @RequestParam(required = false)
                                                          @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant dateTo,
                                                          @RequestParam(defaultValue = "1") long page,
                                                          @RequestParam(defaultValue = "20") long size) {
        return ApiResponse.ok(service.list(actorUsername, action, targetType, targetId,
                result, dateFrom, dateTo, page, size));
    }

    @GetMapping("/{uuid}")
    @RequiresPermission("audit:list")
    public ApiResponse<AdminAuditLogDetailResponse> detail(@PathVariable String uuid) {
        return ApiResponse.ok(service.detail(uuid));
    }
}
