package com.qingzhang.reports.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.util.List;

/** 年报 spec §7.2。 */
public record YearlyReportResponse(
        @JsonProperty("year")              Integer year,
        @JsonProperty("totalIncome")       BigDecimal totalIncome,
        @JsonProperty("totalExpense")      BigDecimal totalExpense,
        @JsonProperty("netSavings")        BigDecimal netSavings,
        @JsonProperty("monthlyData")       List<MonthlyPoint> monthlyData,
        @JsonProperty("incomeByCategory")  List<CategoryTotal> incomeByCategory,
        @JsonProperty("expenseByCategory") List<CategoryTotal> expenseByCategory
) {}