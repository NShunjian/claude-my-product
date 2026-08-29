package com.qingzhang.accounts.dto;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * POST /api/accounts 入参。
 *
 * 业务校验(非空/格式/范围)走 JSR-380;
 * 业务规则(is_default 单选)在 service 校验。
 */
public record CreateAccountRequest(
        @NotBlank @Size(max = 20) String name,
        @NotBlank @Pattern(regexp = "cash|debit|credit|wallet|investment|other") String type,
        @NotBlank @Size(max = 32) String icon,
        @DecimalMin("0.00") BigDecimal initialBalance,
        @Size(min = 3, max = 3) String currency,
        Boolean isDefault,
        Integer sortOrder,
        @Size(max = 255) String note
) {}
