package com.qingzhang.books.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;

/**
 * GET /api/books 返回单个账本。role 字段表示当前用户在该账本的角色。
 */
public record BookResponse(
        @JsonProperty("uuid")         String uuid,
        @JsonProperty("name")         String name,
        @JsonProperty("description")  String description,
        @JsonProperty("type")         String type,
        @JsonProperty("currency")     String currency,
        @JsonProperty("isDefault")    boolean isDefault,
        @JsonProperty("isArchived")   boolean isArchived,
        @JsonProperty("role")         String role,
        @JsonProperty("ownerUuid")    String ownerUuid,
        @JsonProperty("createdAt")    Instant createdAt,
        @JsonProperty("updatedAt")    Instant updatedAt
) {}
