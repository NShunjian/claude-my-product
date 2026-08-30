package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.*;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;

/**
 * 用户-角色授权表(admin_user_roles) —— MyBatis-Plus。
 *
 * V6 改造:user_id -> admin_user_id(FK 指向 admin_users.id 而非 users.id)
 */
@Getter @Setter @NoArgsConstructor @AllArgsConstructor
@TableName("admin_user_roles")
public class AdminUserRole implements Serializable {
    private Long adminUserId;
    private Long roleId;
    private Instant grantedAt;
    private Long grantedBy;

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof AdminUserRole that)) return false;
        return Objects.equals(adminUserId, that.adminUserId) && Objects.equals(roleId, that.roleId);
    }
    @Override public int hashCode() { return Objects.hash(adminUserId, roleId); }
}