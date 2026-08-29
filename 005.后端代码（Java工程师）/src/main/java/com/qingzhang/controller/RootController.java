package com.qingzhang.controller;

import com.qingzhang.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 根路径友好响应 — 避免访问 :4001/ 时落到通用异常拦截器返回 1500。
 * 其余路径(/api/...)的 404 仍由 GlobalExceptionHandler 报 1500,符合预期。
 *
 * ponytail: 只一个 handler,加完就够。
 */
@RestController
public class RootController {

    @GetMapping("/")
    public ApiResponse<Map<String, String>> root() {
        return ApiResponse.ok(Map.of(
                "service", "qingzhang-java-backend",
                "api",     "/api/*  (需 Authorization: Bearer <token>)",
                "health",  "/api/version"
        ));
    }
}
