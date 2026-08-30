package com.qingzhang.admin.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;
import java.util.List;

/**
 * 管理员详情响应。
 *
 * 全局 jackson.default-property-inclusion=non_null 会把 null 字段从 JSON 里抹掉,
 * 前端收到的是"字段不存在"。但管理员详情里的 avatar/gender/age/email/phone 是
 * AdminUser 实体没有的字段(V6 拆分后,管理员不再继承普通用户的 profile 字段),
 * 需要始终序列化 —— 前端才能识别"管理员没这个字段",显示 --。
 */
@JsonInclude(JsonInclude.Include.ALWAYS)
public record AdminUserDetailResponse(
    long id, String uuid, String username, String displayName,
    String avatar, String gender, Integer age, String email, String phone,
    Byte status, Instant lastLoginAt, Instant createdAt,
    List<String> roles
) {}
