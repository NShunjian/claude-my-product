package com.qingzhang.reports.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.util.List;

/** 月报 spec §7.1。 */
public record MonthlyReportResponse(
        @JsonProperty("month")             String month,
        @JsonProperty("totalIncome")        BigDecimal totalIncome,
        @JsonProperty("totalExpense")       BigDecimal totalExpense,
        @JsonProperty("netSavings")         BigDecimal netSavings,
        @JsonProperty("lastMonth")          @JsonInclude(JsonInclude.Include.ALWAYS) LastMonth lastMonth,
        @JsonProperty("incomeByCategory")   List<CategoryTotal> incomeByCategory,
        @JsonProperty("expenseByCategory")  List<CategoryTotal> expenseByCategory,
        @JsonProperty("dailyData")          List<DailyPoint> dailyData
) {
    public record LastMonth(
            @JsonProperty("totalIncome")  BigDecimal totalIncome,
            @JsonProperty("totalExpense") BigDecimal totalExpense,
            @JsonProperty("netSavings")   BigDecimal netSavings
    ) {}
}