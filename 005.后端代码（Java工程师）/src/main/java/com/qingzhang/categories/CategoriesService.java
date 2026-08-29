package com.qingzhang.categories;

import com.qingzhang.categories.dto.CategoryResponse;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * 分类只读:返回预设分类 + 当前用户自定义分类(若有 V1.1)。
 *
 * spec §5.3:50xx 分类域;当前只读,暂不分配错误码。
 */
@Service
public class CategoriesService {

    private final CategoryMapper categoryMapper;

    public CategoriesService(CategoryMapper categoryMapper) {
        this.categoryMapper = categoryMapper;
    }

    public List<CategoryResponse> list(long userId, String type) {
        return categoryMapper.selectList(
                Wrappers.<Category>lambdaQuery()
                        .and(w -> w.isNull(Category::getUserId).or().eq(Category::getUserId, userId))
                        .eq(Category::getIsActive, (byte) 1)
                        .eq(type != null, Category::getType, type)
                        .orderByAsc(Category::getSortOrder)
        ).stream().map(this::toResponse).toList();
    }

    private CategoryResponse toResponse(Category c) {
        return new CategoryResponse(
                c.getUuid(),
                c.getType(),
                c.getName(),
                c.getIcon(),
                c.getColor(),
                c.getSortOrder()
        );
    }
}
