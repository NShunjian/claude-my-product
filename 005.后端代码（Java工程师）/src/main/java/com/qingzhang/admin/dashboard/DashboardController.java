package com.qingzhang.admin.dashboard;

import com.qingzhang.admin.dto.AdminDashboardStats;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/dashboard")
public class DashboardController {

    private final DashboardService service;

    public DashboardController(DashboardService service) {
        this.service = service;
    }

    @GetMapping
    @RequiresPermission("dashboard:view")
    public ApiResponse<AdminDashboardStats> stats() {
        return ApiResponse.ok(service.stats());
    }
}
