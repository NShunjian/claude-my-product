package com.qingzhang.books.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * PATCH /api/books/{uuid} 入参。所有字段可选(PATCH 部分更新语义)。
 *
 * 注:不允许改 owner/role;bookId 由 URL 决定。
 */
public record UpdateBookRequest(
        @Size(max = 50) String name,
        @Size(max = 255) String description,
        @Pattern(regexp = "personal|shared|business") String type,
        Boolean isArchived
) {}
