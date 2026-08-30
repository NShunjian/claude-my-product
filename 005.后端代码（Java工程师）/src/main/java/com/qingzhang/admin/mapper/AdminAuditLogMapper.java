package com.qingzhang.admin.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.admin.entity.AdminAuditLog;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface AdminAuditLogMapper extends BaseMapper<AdminAuditLog> {
}