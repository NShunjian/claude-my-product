package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.*;
import java.time.Instant;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
@TableName("admin_roles")
public class AdminRole {
    @TableId(type = IdType.AUTO) private Long id;
    private String uuid;
    private String code;
    private String name;
    private String description;
    private Byte status;
    private Instant createdAt;
    private Instant updatedAt;

    @TableLogic @TableField(select = false) private Instant deletedAt;
}
