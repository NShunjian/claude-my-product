package com.qingzhang.reports;

import com.qingzhang.books.BooksService;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.reports.mapper.ReportMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;

/**
 * 005 Java 后端 — ReportsService 输入校验测试(占位骨架)
 *
 * 覆盖目标(按 005-java-backend.md §7.2):
 *   - 4001 BAD_MONTH     → "2026-9" 非 YYYY-MM 格式
 *   - 4002 BAD_YEAR      → year 越界 [1900, 9999]
 *   - 跨年 month=2026-01  → 上月 = 2025-12(由 SQL 断言聚合期间正确)
 *   - 缺失日补 0         → dailyData 31 天全部 0
 *
 * 状态:骨架。完整路径需 @SpringBootTest + H2 内存库跑报表 SQL。
 */
class ReportsServiceMonthFormatTest {

    private final ReportMapper reportMapper = mock(ReportMapper.class);
    private final CategoryMapper categoryMapper = mock(CategoryMapper.class);
    private final BooksService booksService = mock(BooksService.class);
    private final ReportsService service = new ReportsService(
        reportMapper, categoryMapper, booksService
    );

    @Test
    @DisplayName("4001 BAD_MONTH — month 格式错抛 BizException")
    void badMonth() {
        var ex = assertThrows(BizException.class, () -> service.monthly(1L, "2026-9", null));
        assertEquals(4001, ex.getCode());
    }

    @Test
    @DisplayName("4002 BAD_YEAR — year=1899 抛 BizException")
    void badYear() {
        var ex = assertThrows(BizException.class, () -> service.yearly(1L, 1899, null));
        assertEquals(4002, ex.getCode());
    }

    @Test
    @DisplayName("4002 BAD_YEAR — year=10000 抛 BizException")
    void badYearTooLarge() {
        var ex = assertThrows(BizException.class, () -> service.yearly(1L, 10000, null));
        assertEquals(4002, ex.getCode());
    }
}