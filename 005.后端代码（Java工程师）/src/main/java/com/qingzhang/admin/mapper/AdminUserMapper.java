package com.qingzhang.admin.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.admin.entity.AdminUser;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface AdminUserMapper extends BaseMapper<AdminUser> {

    // ====== admin 硬删用 —— 绕过 @TableLogic ======

    /** 硬删一个管理员账号(绕过 @TableLogic)。FK CASCADE 自动清 admin_user_roles。 */
    @Delete("DELETE FROM admin_users WHERE id = #{id}")
    int hardDeleteById(@Param("id") Long id);

    /** 硬删一个管理员(若存在且未软删)。返回 1 = 真删, 0 = 不存在 / 已软删。 */
    @Delete("DELETE FROM admin_users WHERE id = #{id} AND deleted_at IS NULL")
    int hardDeleteByIdLive(@Param("id") Long id);

    /** 检查管理员是否还活着(未被软删)。1 = 活, 0 = 已软删 / 不存在。 */
    @Select("SELECT EXISTS(SELECT 1 FROM admin_users WHERE id = #{id} AND deleted_at IS NULL)")
    int existsLive(@Param("id") Long id);
}
