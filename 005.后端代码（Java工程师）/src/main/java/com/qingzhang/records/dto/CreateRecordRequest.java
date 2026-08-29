package com.qingzhang.records.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.DecimalMin;
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
 */
public record CreateRecordRequest(
        @JsonProperty("type")          @NotBlank  String type,
        @JsonProperty("categoryId")                 String categoryId,
        @JsonProperty("accountId")     @NotBlank  String accountId,
        @JsonProperty("toAccountId")                String toAccountId,
        @JsonProperty("amount")        @NotNull @DecimalMin(value = "0.01") BigDecimal amount,
        @JsonProperty("recordDate")    @NotBlank  String recordDate,
        @JsonProperty("note")          @Size(max = 50) String note,
        @JsonProperty("clientId")      @Size(max = 64) String clientId
) {}