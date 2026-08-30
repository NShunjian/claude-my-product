package com.qingzhang.admin.entity;

import lombok.*;
import java.io.Serializable;
import java.time.Instant;
import java.util.Objects;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class AdminUserRole implements Serializable {
    private Long userId;
    private Long roleId;
    private Instant grantedAt;
    private Long grantedBy;

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof AdminUserRole that)) return false;
        return Objects.equals(userId, that.userId) && Objects.equals(roleId, that.roleId);
    }
    @Override public int hashCode() { return Objects.hash(userId, roleId); }
}
