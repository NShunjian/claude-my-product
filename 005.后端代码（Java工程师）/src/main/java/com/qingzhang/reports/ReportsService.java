package com.qingzhang.reports;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.books.BooksService;
import com.qingzhang.books.entity.Book;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.reports.dto.CategoryTotal;
import com.qingzhang.reports.dto.DailyPoint;
import com.qingzhang.reports.dto.MonthlyPoint;
import com.qingzhang.reports.dto.MonthlyReportResponse;
import com.qingzhang.reports.dto.YearlyReportResponse;
import com.qingzhang.reports.mapper.ReportMapper;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 报表域业务(spec §7.1-7.2)。
 *
 * 错误码:40xx 报表域。当前仅 VALIDATION_FAILED(月份/年份格式错)。
 *
 * 设计要点:
 *   1. 所有聚合走 SQL,不在 Java 内存里跑循环。
 *   2. 分类汇总后,需要再用 CategoryMapper 反查一次拿到 name/icon/color(uuid 形式)。
 *   3. dailyData/monthlyData 缺失的日子/月补 0,确保前端能拿到完整序列。
 *   4. V1.1:可按 bookId 过滤;空 → 用户所有账本;非空 → 必须是可访问账本。
 */
@Service
public class ReportsService {

    private static final int CODE_BAD_MONTH = 4001;
    private static final int CODE_BAD_YEAR  = 4002;

    private final ReportMapper reportMapper;
    private final CategoryMapper categoryMapper;
    private final BooksService booksService;

    public ReportsService(ReportMapper reportMapper,
                          CategoryMapper categoryMapper,
                          BooksService booksService) {
        this.reportMapper = reportMapper;
        this.categoryMapper = categoryMapper;
        this.booksService = booksService;
    }

    // ===== 月报 =====

    public MonthlyReportResponse monthly(long userId, String monthStr, String bookUuid) {
        YearMonth ym = parseMonth(monthStr);
        LocalDate from = ym.atDay(1);
        LocalDate to   = ym.atEndOfMonth();
        Long bookId = resolveBookId(userId, bookUuid);

        BigDecimal totalIncome  = zeroOnNull(reportMapper.sumByMonth(userId, bookId, from, to).get("total_income"));
        BigDecimal totalExpense = zeroOnNull(reportMapper.sumByMonth(userId, bookId, from, to).get("total_expense"));
        BigDecimal netSavings   = totalIncome.subtract(totalExpense);

        // 上月(可能跨年,用 YearMonth.minusMonths)
        YearMonth prevYm = ym.minusMonths(1);
        BigDecimal prevIncome  = zeroOnNull(reportMapper.sumByMonth(userId, bookId, prevYm.atDay(1), prevYm.atEndOfMonth()).get("total_income"));
        BigDecimal prevExpense = zeroOnNull(reportMapper.sumByMonth(userId, bookId, prevYm.atDay(1), prevYm.atEndOfMonth()).get("total_expense"));

        List<CategoryTotal> incomeByCat  = categoryTotals(userId, "income",  bookId, from, to);
        List<CategoryTotal> expenseByCat = categoryTotals(userId, "expense", bookId, from, to);
        List<DailyPoint> dailyData = dailyData(ym, reportMapper.dailySum(userId, bookId, from, to));

        MonthlyReportResponse.LastMonth lastMonth =
                new MonthlyReportResponse.LastMonth(prevIncome, prevExpense, prevIncome.subtract(prevExpense));

        return new MonthlyReportResponse(
                monthStr,
                totalIncome, totalExpense, netSavings,
                lastMonth,
                incomeByCat, expenseByCat, dailyData
        );
    }

    // ===== 年报 =====

    public YearlyReportResponse yearly(long userId, int year, String bookUuid) {
        if (year < 1900 || year > 9999) {
            throw new BizException(CODE_BAD_YEAR, "year 必须在 1900-9999 之间");
        }
        LocalDate from = LocalDate.of(year, 1, 1);
        LocalDate to   = LocalDate.of(year, 12, 31);
        Long bookId = resolveBookId(userId, bookUuid);

        BigDecimal totalIncome  = zeroOnNull(reportMapper.sumByMonth(userId, bookId, from, to).get("total_income"));
        BigDecimal totalExpense = zeroOnNull(reportMapper.sumByMonth(userId, bookId, from, to).get("total_expense"));

        List<CategoryTotal> expenseByCat = categoryTotals(userId, "expense", bookId, from, to);
        List<MonthlyPoint> monthlyData = monthlyData(year, reportMapper.monthlySum(userId, bookId, from, to));

        return new YearlyReportResponse(
                year, totalIncome, totalExpense,
                totalIncome.subtract(totalExpense),
                monthlyData, expenseByCat
        );
    }

    // ===== 工具 =====

    /** 解析 YYYY-MM → YearMonth。 */
    private static YearMonth parseMonth(String s) {
        try {
            return YearMonth.parse(s);
        } catch (DateTimeParseException | NullPointerException ex) {
            throw new BizException(CODE_BAD_MONTH, "month 必须是 YYYY-MM 格式");
        }
    }

    /** bookId 解析:空 → null(不限账本);非空 → 必须可访问,取 internal book id。 */
    private Long resolveBookId(long userId, String bookUuid) {
        if (bookUuid == null || bookUuid.isBlank()) return null;
        return booksService.mustAccessibleBook(userId, bookUuid).getId();
    }

    /** 分类汇总 + 反查 name/icon/color。 */
    private List<CategoryTotal> categoryTotals(long userId, String type, Long bookId, LocalDate from, LocalDate to) {
        List<Map<String, Object>> rows = reportMapper.sumByCategory(userId, type, bookId, from, to);
        if (rows.isEmpty()) return List.of();

        // 收集涉及的 categoryId
        List<Long> ids = rows.stream()
                .map(r -> ((Number) r.get("category_id")).longValue())
                .toList();
        Map<Long, Category> catById = categoryMapper.selectBatchIds(ids).stream()
                .collect(Collectors.toMap(Category::getId, c -> c));

        List<CategoryTotal> out = new ArrayList<>(rows.size());
        for (Map<String, Object> row : rows) {
            Long catId = ((Number) row.get("category_id")).longValue();
            Category c = catById.get(catId);
            if (c == null) continue; // 分类被删 → 跳过
            out.add(new CategoryTotal(
                    c.getUuid(),
                    c.getName(),
                    c.getIcon(),
                    c.getColor(),
                    (BigDecimal) row.get("total")
            ));
        }
        return out;
    }

    /** dailyData:缺失日补 0。 */
    private List<DailyPoint> dailyData(YearMonth ym, List<Map<String, Object>> rows) {
        Map<Integer, BigDecimal[]> byDay = new HashMap<>();
        for (Map<String, Object> row : rows) {
            int day = ((Number) row.get("day")).intValue();
            byDay.put(day, new BigDecimal[]{
                    (BigDecimal) row.get("income"),
                    (BigDecimal) row.get("expense")
            });
        }
        List<DailyPoint> out = new ArrayList<>(ym.lengthOfMonth());
        for (int d = 1; d <= ym.lengthOfMonth(); d++) {
            BigDecimal[] arr = byDay.get(d);
            if (arr == null) {
                out.add(new DailyPoint(d, BigDecimal.ZERO, BigDecimal.ZERO));
            } else {
                out.add(new DailyPoint(d, arr[0], arr[1]));
            }
        }
        return out;
    }

    /** monthlyData:缺失月补 0。 */
    private List<MonthlyPoint> monthlyData(int year, List<Map<String, Object>> rows) {
        Map<Integer, BigDecimal[]> byMonth = new HashMap<>();
        for (Map<String, Object> row : rows) {
            int m = ((Number) row.get("month")).intValue();
            byMonth.put(m, new BigDecimal[]{
                    (BigDecimal) row.get("income"),
                    (BigDecimal) row.get("expense")
            });
        }
        List<MonthlyPoint> out = new ArrayList<>(12);
        for (int m = 1; m <= 12; m++) {
            BigDecimal[] arr = byMonth.get(m);
            if (arr == null) {
                out.add(new MonthlyPoint(m, BigDecimal.ZERO, BigDecimal.ZERO));
            } else {
                out.add(new MonthlyPoint(m, arr[0], arr[1]));
            }
        }
        return out;
    }

    private static BigDecimal zeroOnNull(Object o) {
        return o == null ? BigDecimal.ZERO : (BigDecimal) o;
    }
}
