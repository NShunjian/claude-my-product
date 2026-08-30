package com.qingzhang.users.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.users.entity.User;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * users 表 BaseMapper。复杂 SQL 走同包 xml/UserMapper.xml。
 */
@Mapper
public interface UserMapper extends BaseMapper<User> {

    /** 该用户激活的 admin 角色 code 集合 (DISTINCT, 软删角色已排除)。 */
    List<String> selectAdminRoleCodesByUserId(@Param("userId") long userId);

    /** 该用户激活角色下所有 admin 权限 code 集合 (DISTINCT, 经 admin_roles.status=1 过滤)。 */
    List<String> selectAdminPermissionsByUserId(@Param("userId") long userId);
}
