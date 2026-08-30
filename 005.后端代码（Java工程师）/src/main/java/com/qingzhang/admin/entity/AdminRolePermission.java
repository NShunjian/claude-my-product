package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.TableName;
import lombok.*;
import java.io.Serializable;
import java.util.Objects;

@Getter @Setter @NoArgsConstructor @AllArgsConstructor
@TableName("admin_role_permissions")
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
