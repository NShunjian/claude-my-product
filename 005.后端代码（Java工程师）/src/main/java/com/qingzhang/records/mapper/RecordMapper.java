package com.qingzhang.records.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.records.entity.Record;
import org.apache.ibatis.annotations.Mapper;

@Mapper
public interface RecordMapper extends BaseMapper<Record> {
}