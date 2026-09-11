package com.qingzhang.accounts.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * POST /api/accounts 入参。
 *
 * 业务校验(非空/格式/范围)走 JSR-380;
 * 业务规则(is_default 单选、bookId 归属、currency 一致性)在 service 校验。
 *
 * V1.2 金额核算审计:initialBalance 显式收紧到 DECIMAL(14,2) 同型
 * (integer=14 fraction=2 = 12 位整数 + 2 位小数 = 999999999999.99),
 * 与 accounts.initial_balance 列严格对齐,避免 MySQL sql_mode 下的静默截断/四舍五入。
 */
public record CreateAccountRequest(
        @NotBlank @Size(max = 20) String name,
        @NotBlank @Pattern(regexp = "cash|debit|credit|wallet|investment|other") String type,
        @NotBlank @Size(max = 32) String icon,
        @DecimalMin("0.00") @Digits(integer = 12, fraction = 2) @DecimalMax("999999999999.99") BigDecimal initialBalance,
        @Size(min = 3, max = 3) String currency,
        Boolean isDefault,
        Integer sortOrder,
        @Size(max = 255) String note,
        @Size(max = 36) String bookId
) {}
