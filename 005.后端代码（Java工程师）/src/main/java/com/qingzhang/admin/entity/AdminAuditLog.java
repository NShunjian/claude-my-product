package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.*;
import java.time.Instant;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
@TableName("admin_audit_logs")
public class AdminAuditLog {
    @TableId(type = IdType.AUTO) private Long id;
    private String uuid;

    /** V6 split:列名 actor_admin_user_id,引用 admin_users.id(从 1000 起) */
    @TableField("actor_admin_user_id")
    private Long actorAdminUserId;

    private String actorUsername;
    private String action;
    private String targetType;
    private Long targetId;
    private String beforeSnapshot;
    private String afterSnapshot;
    private String ip;
    private String userAgent;
    private String result;
    private String errorMsg;
    private Instant createdAt;
}