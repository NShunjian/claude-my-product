package com.qingzhang.admin.dto;
import java.time.Instant;
public record AdminUserListItem(
    long id, String uuid, String username, String displayName,
    Byte status, Instant lastLoginAt, Instant createdAt,
    int recordCount, int bookCount
) {}
