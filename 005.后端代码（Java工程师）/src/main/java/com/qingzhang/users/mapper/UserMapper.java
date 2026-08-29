package com.qingzhang.users.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.users.entity.User;
import org.apache.ibatis.annotations.Mapper;

/**
 * users 表 BaseMapper。复杂 SQL 走同包 xml/UserMapper.xml(spec §6.2)。
 */
@Mapper
public interface UserMapper extends BaseMapper<User> {
}
