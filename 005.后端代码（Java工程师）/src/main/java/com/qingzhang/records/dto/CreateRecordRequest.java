package com.qingzhang.records.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Digits;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

/**
 * 创建账目请求。
 *
 * 前端是按 type 字段做 discriminator 的 union 类型;后端这边用一份 record 容纳三种形态,
 * 字段都按"可有可无"标 nullable,真正的 type → 必填字段校验放到 Service 层做
 * (避免 Jackson 多态序列化 + JSR-380 嵌套校验的复杂性)。
 *
 * V1.1:可选 bookId,缺省走用户默认账本。
 *
 * V1.2 金额核算审计:amount 显式收紧到 DECIMAL(12,2) 同型(integer=10 fraction=2),
 * 与 records.amount 列严格对齐,避免 MySQL sql_mode 下的静默截断/四舍五入,
 * 并阻止客户端提交 0.001、1e10 这类不合法值。
 */
public record CreateRecordRequest(
        @JsonProperty("type")          @NotBlank  String type,
        @JsonProperty("categoryId")                 String categoryId,
        @JsonProperty("accountId")     @NotBlank  String accountId,
        @JsonProperty("toAccountId")                String toAccountId,
        @JsonProperty("amount")        @NotNull @DecimalMin(value = "0.01") @Digits(integer = 10, fraction = 2) @DecimalMax("9999999999.99") BigDecimal amount,
        @JsonProperty("recordDate")    @NotBlank  String recordDate,
        @JsonProperty("note")          @Size(max = 50) String note,
        @JsonProperty("clientId")      @Size(max = 64) String clientId,
        @JsonProperty("bookId")        @Size(max = 36) String bookId
) {}
