package com.qingzhang.admin.dto;
public record AdminPresetCategoryRequest(
    String type, String name, String icon, String color, Integer sortOrder
) {}
