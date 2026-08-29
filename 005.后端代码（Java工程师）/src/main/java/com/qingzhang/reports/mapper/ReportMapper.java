package com.qingzhang.reports.mapper;

import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

@Mapper
public interface ReportMapper {

    /** 月总收支:返回单行 (income, expense)。bookId 为 null 时不限账本。 */
    @Select("""
            SELECT
              COALESCE(SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END), 0) AS total_income,
              COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense
            FROM records
            WHERE user_id = #{userId}
              AND deleted_at IS NULL
              AND (#{bookId} IS NULL OR book_id = #{bookId})
              AND record_date >= #{from}
              AND record_date <= #{to}
            """)
    Map<String, BigDecimal> sumByMonth(@Param("userId") long userId,
                                      @Param("bookId") Long bookId,
                                      @Param("from") LocalDate from,
                                      @Param("to")   LocalDate to);

    /**
     * 按分类汇总(单月):{category_id, total}。
     * transfer 不计入「按分类」(spec §7.1)。
     */
    @Select("""
            SELECT category_id AS category_id, SUM(amount) AS total
            FROM records
            WHERE user_id = #{userId}
              AND type = #{type}
              AND deleted_at IS NULL
              AND (#{bookId} IS NULL OR book_id = #{bookId})
              AND record_date >= #{from}
              AND record_date <= #{to}
              AND category_id IS NOT NULL
            GROUP BY category_id
            ORDER BY total DESC
            """)
    List<Map<String, Object>> sumByCategory(@Param("userId") long userId,
                                            @Param("type")  String type,
                                            @Param("bookId") Long bookId,
                                            @Param("from")  LocalDate from,
                                            @Param("to")    LocalDate to);

    /** 月度日分布:{day, income, expense}(只返有数据的日子)。 */
    @Select("""
            SELECT
              DAY(record_date) AS day,
              COALESCE(SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END), 0) AS income,
              COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
            FROM records
            WHERE user_id = #{userId}
              AND deleted_at IS NULL
              AND (#{bookId} IS NULL OR book_id = #{bookId})
              AND record_date >= #{from}
              AND record_date <= #{to}
            GROUP BY DAY(record_date)
            """)
    List<Map<String, Object>> dailySum(@Param("userId") long userId,
                                       @Param("bookId") Long bookId,
                                       @Param("from")  LocalDate from,
                                       @Param("to")    LocalDate to);

    /** 年度月分布:{month, income, expense}(只返有数据的月)。 */
    @Select("""
            SELECT
              MONTH(record_date) AS month,
              COALESCE(SUM(CASE WHEN type = 'income'  THEN amount ELSE 0 END), 0) AS income,
              COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
            FROM records
            WHERE user_id = #{userId}
              AND deleted_at IS NULL
              AND (#{bookId} IS NULL OR book_id = #{bookId})
              AND record_date >= #{from}
              AND record_date <= #{to}
            GROUP BY MONTH(record_date)
            """)
    List<Map<String, Object>> monthlySum(@Param("userId") long userId,
                                         @Param("bookId") Long bookId,
                                         @Param("from")  LocalDate from,
                                         @Param("to")    LocalDate to);
}
