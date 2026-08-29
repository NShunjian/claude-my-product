package com.qingzhang.reports.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;

/** 月报里的某一天收支。 */
public record DailyPoint(
        @JsonProperty("day")     Integer day,
        @JsonProperty("income")  BigDecimal income,
        @JsonProperty("expense") BigDecimal expense
) {}