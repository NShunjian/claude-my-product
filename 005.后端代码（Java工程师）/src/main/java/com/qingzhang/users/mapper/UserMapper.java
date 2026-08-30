package com.qingzhang.users.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.users.entity.User;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

/**
 * users 表 BaseMapper。复杂 SQL 走同包 xml/UserMapper.xml。
 *
 * hardDeleteXxx 方法绕过 @TableLogic 走原生 SQL,供 admin 彻底删除用 —— 不可恢复。
 */
@Mapper
public interface UserMapper extends BaseMapper<User> {

    /** 硬删一个用户(绕过 @TableLogic)。返回受影响行数(0 = 不存在或已被硬删)。 */
    @Delete("DELETE FROM users WHERE id = #{id}")
    int hardDeleteById(@Param("id") Long id);

    /** 硬删一个用户(若存在且未软删)。返回 1 = 真删, 0 = 不存在 / 已被软删。 */
    @Delete("DELETE FROM users WHERE id = #{id} AND deleted_at IS NULL")
    int hardDeleteByIdLive(@Param("id") Long id);

    /** 检查用户是否还活着(未被软删)。1 = 活, 0 = 已软删 / 不存在。 */
    @Select("SELECT EXISTS(SELECT 1 FROM users WHERE id = #{id} AND deleted_at IS NULL)")
    int existsLive(@Param("id") Long id);
}
