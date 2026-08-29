package com.qingzhang.categories;

import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.categories.dto.CategoryResponse;
import com.qingzhang.categories.dto.CreateCategoryRequest;
import com.qingzhang.categories.dto.UpdateCategoryRequest;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
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

import java.util.List;
import java.util.Map;

/**
 *   GET    /api/categories[?type=expense|income] -> {items:[Category]}
 *   POST   /api/categories                       -> {category:Category}
 *   PATCH  /api/categories/{uuid}                -> {category:Category}
 *   DELETE /api/categories/{uuid}                -> {ok:true}
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

    @PostMapping
    public ApiResponse<Map<String, Object>> create(HttpServletRequest req,
                                                    @Valid @RequestBody CreateCategoryRequest body) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("category", service.create(userId, body)));
    }

    @PatchMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> update(HttpServletRequest req,
                                                    @PathVariable String uuid,
                                                    @Valid @RequestBody UpdateCategoryRequest body) {
        long userId = userId(req);
        return ApiResponse.ok(Map.of("category", service.update(userId, uuid, body)));
    }

    @DeleteMapping("/{uuid}")
    public ApiResponse<Map<String, Object>> delete(HttpServletRequest req,
                                                    @PathVariable String uuid) {
        long userId = userId(req);
        service.delete(userId, uuid);
        return ApiResponse.ok(Map.of("ok", true));
    }

    private static long userId(HttpServletRequest req) {
        Long id = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (id == null) throw new BizException(ErrorCode.UNAUTHORIZED, "未登录");
        return id;
    }
}
