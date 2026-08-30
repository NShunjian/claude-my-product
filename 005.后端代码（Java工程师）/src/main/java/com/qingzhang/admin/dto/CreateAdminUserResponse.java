package com.qingzhang.admin.dto;

/**
 * 创建管理员响应 —— 新账号 id / username / 一次性明文密码。
 * 创建者把密码当面转给新管理员(后续可用 resetPassword 重置)。
 */
public record CreateAdminUserResponse(
        long id,
        String username,
        String password
) {
}