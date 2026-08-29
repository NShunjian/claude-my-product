package com.qingzhang.categories;

import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.categories.dto.CategoryResponse;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 *   GET /api/categories[?type=expense|income]   -> {items:[Category]}
 *
 * 只读,不分页(spec §5.4:列表项 ≤ 20 个才不分页)。
 */
@RestController
@RequestMapping("/api/categories")
public class CategoriesController {

    private final CategoriesService service;

    public CategoriesController(CategoriesService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<Map<String, Object>> list(HttpServletRequest req,
                                                  @RequestParam(required = false) String type) {
        long userId = userId(req);
        if (type != null && !type.equals("expense") && !type.equals("income")) {
            throw new BizException(ErrorCode.VALIDATION_FAILED, "type 必须是 expense 或 income");
        }
        List<CategoryResponse> items = service.list(userId, type);
        return ApiResponse.ok(Map.of("items", items));
    }

    private static long userId(HttpServletRequest req) {
        Long id = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (id == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED, "未登录");
        }
        return id;
    }
}
