package com.qingzhang.categories.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * POST /api/categories 入参。自定义分类(用户级全局)。
 */
public record CreateCategoryRequest(
        @NotBlank @Pattern(regexp = "expense|income") String type,
        @NotBlank @Size(max = 20) String name,
        // icon 允许为空:前端「没填图片」时存空串,渲染层走纯色填充(disp.solid=true)
        @Size(max = 32) String icon,
        @Size(max = 16) String color,
        Integer sortOrder
) {}
