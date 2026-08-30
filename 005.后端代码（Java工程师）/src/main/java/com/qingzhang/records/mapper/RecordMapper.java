package com.qingzhang.records.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.records.entity.Record;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface RecordMapper extends BaseMapper<Record> {

    // ====== admin 硬删用 —— 绕过 @TableLogic ======

    /** 硬删某用户所有流水(绕过 @TableLogic)。必须在硬删 books 之前调用,否则 records.book_id RESTRICT 拒删。 */
    @Delete("DELETE FROM records WHERE user_id = #{userId}")
    int hardDeleteByUserId(@Param("userId") Long userId);

    /** 统计某用户的流水数(含已被软删的)。供硬删前预览用。 */
    @Select("SELECT COUNT(*) FROM records WHERE user_id = #{userId}")
    int countByUserId(@Param("userId") Long userId);
}
