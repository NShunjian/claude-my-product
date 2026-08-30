package com.qingzhang.admin.records;

import com.qingzhang.admin.dto.AdminRecordListItem;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.common.ApiResponse;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;

@RestController
@RequestMapping("/api/admin/records")
public class AdminRecordsController {

    private final AdminRecordService service;

    public AdminRecordsController(AdminRecordService service) {
        this.service = service;
    }

    @GetMapping
    @RequiresPermission("record:list")
    public ApiResponse<Page<AdminRecordListItem>> list(@RequestParam(required = false) Long userId,
                                                        @RequestParam(required = false) String bookUuid,
                                                        @RequestParam(required = false) String type,
                                                        @RequestParam(required = false)
                                                        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateFrom,
                                                        @RequestParam(required = false)
                                                        @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate dateTo,
                                                        @RequestParam(defaultValue = "1") long page,
                                                        @RequestParam(defaultValue = "20") long size) {
        return ApiResponse.ok(service.list(userId, bookUuid, type, dateFrom, dateTo, page, size));
    }
}
