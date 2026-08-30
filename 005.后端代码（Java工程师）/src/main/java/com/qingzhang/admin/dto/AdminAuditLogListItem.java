package com.qingzhang.admin.dto;
import java.time.Instant;
public record AdminAuditLogListItem(
    String uuid, String actorUsername, String action,
    String targetType, Long targetId, String result,
    Instant createdAt
) {}
