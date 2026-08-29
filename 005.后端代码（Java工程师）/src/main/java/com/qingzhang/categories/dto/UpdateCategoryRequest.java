package com.qingzhang.categories.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * PATCH /api/categories/{uuid} 入参。预设(is_preset=1)不可改。
 */
public record UpdateCategoryRequest(
        @Size(max = 20) String name,
        @Size(max = 32) String icon,
        @Size(max = 16) String color,
        @Pattern(regexp = "expense|income") String type,
        Integer sortOrder
) {}
