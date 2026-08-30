package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.*;
import java.time.Instant;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
@TableName("admin_permissions")
public class AdminPermission {
    @TableId(type = IdType.AUTO) private Long id;
    private String code;
    private String name;
    private String resource;
    private String action;
    private Instant createdAt;
    // 无软删
}
