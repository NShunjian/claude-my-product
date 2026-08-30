package com.qingzhang.admin.entity;

import lombok.*;
import java.io.Serializable;
import java.util.Objects;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
public class AdminRolePermission implements Serializable {
    private Long roleId;
    private Long permissionId;

    @Override public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof AdminRolePermission that)) return false;
        return Objects.equals(roleId, that.roleId) && Objects.equals(permissionId, that.permissionId);
    }
    @Override public int hashCode() { return Objects.hash(roleId, permissionId); }
}
