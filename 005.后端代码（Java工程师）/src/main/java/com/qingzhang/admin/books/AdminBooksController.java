package com.qingzhang.admin.books;

import com.qingzhang.admin.books.AdminBookService;
import com.qingzhang.admin.dto.AdminBookListItem;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.admin.security.RequiresPermission;
import com.qingzhang.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/books")
public class AdminBooksController {

    private final AdminBookService service;

    public AdminBooksController(AdminBookService service) {
        this.service = service;
    }

    @GetMapping
    @RequiresPermission("book:list")
    public ApiResponse<Page<AdminBookListItem>> list(@RequestParam(required = false) Long ownerId,
                                                      @RequestParam(required = false) String type,
                                                      @RequestParam(required = false) String search,
                                                      @RequestParam(defaultValue = "1") long page,
                                                      @RequestParam(defaultValue = "20") long size) {
        return ApiResponse.ok(service.list(ownerId, type, search, page, size));
    }
}
