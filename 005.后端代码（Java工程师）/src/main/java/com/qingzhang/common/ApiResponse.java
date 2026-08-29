package com.qingzhang.common;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * 全局统一响应信封。成功与错误都用此形,前端只认这一种:
 *   成功:{ "code": 0,   "message": "ok", "data": { ... } }
 *   失败:{ "code": 4xx, "message": "..." }
 *
 * ponytail: 内部约定 1xxx = 通用参数,2xxx = 业务(用户 10xx/账本 20xx/账目 30xx ...)。
 * 不再依赖任何旧 Node 形状。
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record ApiResponse<T>(int code, String message, T data) {

    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(0, "ok", data);
    }

    public static <T> ApiResponse<T> ok() {
        return new ApiResponse<>(0, "ok", null);
    }

    public static <T> ApiResponse<T> fail(int code, String message) {
        return new ApiResponse<>(code, message, null);
    }
}
