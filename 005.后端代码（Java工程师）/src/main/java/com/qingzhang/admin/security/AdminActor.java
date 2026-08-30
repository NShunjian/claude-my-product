package com.qingzhang.admin.security;

/**
 * 当前 admin 操作人 —— controller 抽出来的 userId/username/ip/userAgent
 * 打包传给 service,service 再透传给 audit 调用方。
 *
 * username 走 UserMapper 查询填入 —— JWT claims 没带 username(为最小化 token 体积)。
 */
public record AdminActor(long userId,
                         String username,
                         String ip,
                         String userAgent) {}
