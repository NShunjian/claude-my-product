package com.qingzhang.categories.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.categories.entity.Category;
import org.apache.ibatis.annotations.Delete;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

@Mapper
public interface CategoryMapper extends BaseMapper<Category> {

    // ====== admin 硬删用 —— 绕过 @TableLogic ======

    /** 硬删某用户所有分类(绕过 @TableLogic)。 */
    @Delete("DELETE FROM categories WHERE user_id = #{userId}")
    int hardDeleteByUserId(@Param("userId") Long userId);

    /** 统计某用户的分类数(含已被软删的)。供硬删前预览用。 */
    @Select("SELECT COUNT(*) FROM categories WHERE user_id = #{userId}")
    int countByUserId(@Param("userId") Long userId);
}
