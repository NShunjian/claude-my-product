package com.qingzhang.books.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * POST /api/books 入参。
 */
public record CreateBookRequest(
        @NotBlank @Size(max = 50) String name,
        @Size(max = 255) String description,
        @Pattern(regexp = "personal|shared|business") String type,
        @Size(min = 3, max = 3) String currency
) {}
