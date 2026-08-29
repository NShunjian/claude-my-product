package com.qingzhang.reports;

import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.reports.dto.MonthlyReportResponse;
import com.qingzhang.reports.dto.YearlyReportResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 *   GET /api/reports/monthly?month=YYYY-MM        -> MonthlyReport
 *   GET /api/reports/yearly?year=YYYY              -> YearlyReport
 *
 * spec §7.1-7.2
 */
@RestController
@RequestMapping("/api/reports")
public class ReportsController {

    private final ReportsService service;

    public ReportsController(ReportsService service) {
        this.service = service;
    }

    @GetMapping("/monthly")
    public ApiResponse<MonthlyReportResponse> monthly(HttpServletRequest req,
                                                      @RequestParam String month) {
        long userId = userId(req);
        return ApiResponse.ok(service.monthly(userId, month));
    }

    @GetMapping("/yearly")
    public ApiResponse<YearlyReportResponse> yearly(HttpServletRequest req,
                                                    @RequestParam int year) {
        long userId = userId(req);
        return ApiResponse.ok(service.yearly(userId, year));
    }

    private static long userId(HttpServletRequest req) {
        Long id = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (id == null) throw new BizException(ErrorCode.UNAUTHORIZED, "未登录");
        return id;
    }
}