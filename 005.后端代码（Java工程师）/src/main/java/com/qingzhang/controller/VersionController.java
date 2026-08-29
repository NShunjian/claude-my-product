package com.qingzhang.controller;

import com.qingzhang.common.ApiResponse;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * 烟雾测试接口,确认工程能起、能路由。
 * ponytail: 接 DB / 安全/业务后保留,仅作存活探针。
 */
@RestController
@RequestMapping("/api/v1")
public class VersionController {

    @GetMapping("/version")
    public ApiResponse<Map<String, String>> version() {
        return ApiResponse.ok(Map.of(
                "name", "qingzhang-java-backend",
                "version", "0.0.1-SNAPSHOT"
        ));
    }
}
