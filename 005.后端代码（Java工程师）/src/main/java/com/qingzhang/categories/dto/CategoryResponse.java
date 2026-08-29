package com.qingzhang.categories.dto;

/**
 * 对齐前端 src/api/categories.ts → Category。
 */
public record CategoryResponse(
        String id,
        String type,
        String name,
        String icon,
        String color,
        Integer sortOrder
) {}
