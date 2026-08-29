package com.qingzhang.records.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

/**
 * 对齐前端 src/api/records.ts → Record(全部 camelCase)。
 *
 * 注:前端字段全是 string ID(uuid 形式),不暴露数据库 id。
 */
public record RecordResponse(
        @JsonProperty("id")                String id,
        @JsonProperty("type")              String type,
        @JsonProperty("categoryId")        String categoryId,
        @JsonProperty("accountId")         String accountId,
        @JsonProperty("toAccountId")       String toAccountId,
        @JsonProperty("amount")            BigDecimal amount,
        @JsonProperty("currency")          String currency,
        @JsonProperty("note")              String note,
        @JsonProperty("recordDate")        LocalDate recordDate,
        @JsonProperty("source")            String source,
        @JsonProperty("clientId")          String clientId,
        @JsonProperty("createdAt")         Instant createdAt,
        @JsonProperty("updatedAt")         Instant updatedAt
) {}