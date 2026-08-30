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

    /** 用户模块 (10xx) —— 跨模块复用 */
    public static final int USER_NOT_FOUND     = 1003;

    /** 系统 */
    public static final int INTERNAL           = 9999;

    /** Admin 模块 (14xx) */
    public static final int ADMIN_AUTH_REQUIRED     = 1411;
    public static final int ADMIN_PERMISSION_DENIED = 1403;
    public static final int ADMIN_USER_NOT_FOUND    = 1410;
    public static final int ADMIN_USER_CONFLICT     = 1413;
    public static final int ADMIN_USER_DISABLED     = 1412;
    public static final int ADMIN_ROLE_NOT_FOUND    = 1420;
    public static final int ADMIN_TARGET_NOT_FOUND  = 1490;
    public static final int ADMIN_BOOTSTRAP_DISABLED = 1499;
}
