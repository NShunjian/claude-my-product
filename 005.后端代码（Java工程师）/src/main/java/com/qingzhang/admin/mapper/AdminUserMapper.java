package com.qingzhang.admin.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.admin.entity.AdminUser;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AdminUserMapper extends BaseMapper<AdminUser> {
}