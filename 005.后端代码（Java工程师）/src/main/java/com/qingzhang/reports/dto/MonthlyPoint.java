package com.qingzhang.reports.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;

/** 年报里的某一月收支。 */
public record MonthlyPoint(
        @JsonProperty("month")   Integer month,
        @JsonProperty("income")  BigDecimal income,
        @JsonProperty("expense") BigDecimal expense
) {}