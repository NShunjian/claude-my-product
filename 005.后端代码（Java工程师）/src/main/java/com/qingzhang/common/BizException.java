package com.qingzhang.common;

/**
 * 业务异常,带数字 code。由 GlobalExceptionHandler 映射为 ApiResponse.fail(code, message)。
 * 约定 code 起点 1xxx(通用)/2xxx+(业务模块),具体见 ApiResponse 注释。
 */
public class BizException extends RuntimeException {

    private final int code;

    public BizException(int code, String message) {
        super(message);
        this.code = code;
    }

    public int getCode() {
        return code;
    }
}
