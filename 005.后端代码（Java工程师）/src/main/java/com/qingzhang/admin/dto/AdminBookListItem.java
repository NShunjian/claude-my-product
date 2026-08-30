package com.qingzhang.admin.dto;
import java.time.Instant;
public record AdminBookListItem(
    String uuid, String name, String type, String currency,
    long ownerId, String ownerUsername, int accountCount, int recordCount,
    Instant createdAt
) {}
