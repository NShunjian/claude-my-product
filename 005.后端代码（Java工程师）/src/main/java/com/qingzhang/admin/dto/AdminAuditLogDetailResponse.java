package com.qingzhang.admin.dto;
import java.time.Instant;
public record AdminAuditLogDetailResponse(
    String uuid, String actorUsername, Long actorUserId,
    String action, String targetType, Long targetId,
    String beforeSnapshot, String afterSnapshot,
    String ip, String userAgent, String result, String errorMsg,
    Instant createdAt
) {}
