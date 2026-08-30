package com.qingzhang.admin.dto;

import java.time.Instant;

/**
 * 预设分类 list item —— 同一 shape 兼作 detail response。
 *
 * ponytail:不拆 detail record —— admin 详情页只需要 name/type/icon/color/sortOrder/
 * isActive + 使用次数,跟列表一样,不值得多一个 DTO。
 */
public record AdminCategoryListItem(
        long id,
        String uuid,
        String type,        // expense / income
        String name,
        String icon,
        String color,
        Integer sortOrder,
        Boolean isActive,
        Instant createdAt,
        Instant updatedAt,
        long usageCount     // 该分类被 records 引用的条数(v1:查 records 表 count)
) {}
