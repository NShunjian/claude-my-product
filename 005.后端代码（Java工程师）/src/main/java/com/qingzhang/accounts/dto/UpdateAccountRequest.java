package com.qingzhang.accounts.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * PATCH /api/accounts/:id 入参,字段全部 nullable(部分更新语义)。
 *
 * 注:V1.1 不允许改 bookId(锁定归属)。bookId 字段保留为 deprecated,忽略。
 */
public record UpdateAccountRequest(
        @Size(max = 20) String name,
        @Pattern(regexp = "cash|debit|credit|wallet|investment|other") String type,
        @Size(max = 32) String icon,
        @DecimalMin("0.00") BigDecimal initialBalance,
        @Size(min = 3, max = 3) String currency,
        Boolean isDefault,
        Integer sortOrder,
        @Size(max = 255) String note,
        @Size(max = 36) String bookId
) {}
