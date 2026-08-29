package com.qingzhang.common;

/**
 * 错误码区间(对齐 Java开发规范 §5.3):
 *   1xxx  通用(参数、鉴权)
 *   10xx  用户
 *   20xx  账本
 *   30xx  账目
 *   40xx  报表
 *   9xxx  系统
 *
 * 模块私有、可预测的业务错误码直接用 BizException(code, msg) 写在 Service 内;
 * 这里只放跨模块复用 + 系统级常量。
 */
public final class ErrorCode {

    private ErrorCode() {}

    /** 通用 */
    public static final int VALIDATION_FAILED   = 1000;
    public static final int UNAUTHORIZED       = 1401;

    /** 系统 */
    public static final int INTERNAL           = 9999;
}
