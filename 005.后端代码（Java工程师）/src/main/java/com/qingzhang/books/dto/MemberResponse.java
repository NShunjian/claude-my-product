package com.qingzhang.books.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;

/**
 * GET /api/books/{uuid}/members 返回单个成员。
 */
public record MemberResponse(
        @JsonProperty("userUuid")    String userUuid,
        @JsonProperty("username")    String username,
        @JsonProperty("displayName") String displayName,
        @JsonProperty("avatar")      String avatar,
        @JsonProperty("role")        String role,
        @JsonProperty("joinedAt")    Instant joinedAt,
        @JsonProperty("invitedBy")   String invitedByUuid
) {}
