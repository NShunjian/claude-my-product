package com.qingzhang.categories.dto;

/**
 * 对齐前端 src/api/categories.ts → Category。
 * 字段名 id,值是 UUID 字符串(实体 categories.uuid)。
 * isPreset 让前端区分「只读预设」与「可改的自定义」。
 */
public record CategoryResponse(
        String id,
        String type,
        String name,
        String icon,
        String color,
        Integer sortOrder,
        Boolean isPreset
) {}
