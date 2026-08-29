package com.qingzhang.records.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.DecimalMin;

import java.math.BigDecimal;

/**
 * 修改账目请求 —— 全部字段可选(Spec §6.3 PATCH 语义)。
 *
 * 注:不允许改 type(只能删了重建),不允许改 userId/bookId。
 * categoryId/toAccountId 用 null 表示「清除关联」(spec §6.3)。
 */
public record UpdateRecordRequest(
        @JsonProperty("categoryId")   String categoryId,
        @JsonProperty("accountId")    String accountId,
        @JsonProperty("toAccountId")  String toAccountId,
        @JsonProperty("amount")       @DecimalMin(value = "0.01") BigDecimal amount,
        @JsonProperty("recordDate")   String recordDate,
        @JsonProperty("note")         String note
) {}