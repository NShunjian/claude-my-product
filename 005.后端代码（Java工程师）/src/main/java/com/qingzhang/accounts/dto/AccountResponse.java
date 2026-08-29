package com.qingzhang.accounts.dto;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * GET 列表 / 详情 / 写后返回的统一 DTO(spec §3.1:出参一律 record)。
 *
 * 对齐前端 src/api/accounts.ts → Account interface。
 */
public record AccountResponse(
        String id,
        String name,
        String type,
        String icon,
        BigDecimal initialBalance,
        BigDecimal balance,
        String currency,
        Boolean isDefault,
        Integer sortOrder,
        String note,
        Instant createdAt
) {}
