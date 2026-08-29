package com.qingzhang.reports.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;

/** 单一分类的金额合计。 */
public record CategoryTotal(
        @JsonProperty("categoryId") String categoryId,
        @JsonProperty("name")       String name,
        @JsonProperty("icon")       String icon,
        @JsonProperty("color")      String color,
        @JsonProperty("total")      BigDecimal total
) {}