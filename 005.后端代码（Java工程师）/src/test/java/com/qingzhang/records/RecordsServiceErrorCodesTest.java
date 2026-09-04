package com.qingzhang.records;

import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.books.BooksService;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.records.dto.CreateRecordRequest;
import com.qingzhang.records.entity.Record;
import com.qingzhang.records.mapper.RecordMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * 005 Java 后端 — RecordsService 错误码触发测试
 *
 * 覆盖目标(按 005-java-backend.md §7.1):
 *   - 3010 INVALID_TYPE              → type 非法
 *   - 3011 CATEGORY_REQUIRED         → expense/income 缺 categoryId
 *   - 3012 CATEGORY_TYPE_MISMATCH    → type=expense + income 类
 *   - 3013 TO_ACCOUNT_REQUIRED       → transfer 缺 toAccountId
 *   - 3014 SAME_ACCOUNT_TRANSFER     → 转出=转入
 *   - 3015 INVALID_RECORD_DATE       → recordDate 非 YYYY-MM-DD
 *   - 3016 ACCOUNT_NOT_FOUND         → 账户不存在
 *   - 3017 ACCOUNT_NOT_IN_BOOK       → 账户不在账本
 *   + happy path:expense 合法入参应跑通
 *
 * 工具:JUnit 5 + Mockito + AssertJ
 */
class RecordsServiceErrorCodesTest {

    private RecordMapper recordMapper;
    private CategoryMapper categoryMapper;
    private AccountMapper accountMapper;
    private BookMapper bookMapper;
    private BooksService booksService;
    private RecordsService service;

    @BeforeEach
    void setUp() {
        recordMapper = mock(RecordMapper.class);
        categoryMapper = mock(CategoryMapper.class);
        accountMapper = mock(AccountMapper.class);
        bookMapper = mock(BookMapper.class);
        booksService = mock(BooksService.class);
        service = new RecordsService(
            recordMapper, categoryMapper, accountMapper, bookMapper, booksService
        );

        // 公共 mock:book 合法且用户可访问(同时 mock defaultBookOf,因为测试用例都未传 bookId)
        Book book = Book.builder()
            .id(100L)
            .uuid(UUID.randomUUID().toString())
            .ownerId(1L)
            .name("个人账本")
            .currency("CNY")
            .build();
        when(booksService.mustAccessibleBook(anyLong(), anyString())).thenReturn(book);
        when(booksService.defaultBookOf(anyLong())).thenReturn(book);

        // 公共 mock:account 合法且在 book 内
        Account account = Account.builder()
            .id(200L)
            .uuid(UUID.randomUUID().toString())
            .userId(1L)
            .bookId(100L)
            .name("微信钱包")
            .currency("CNY")
            .build();
        when(accountMapper.selectOne(any())).thenReturn(account);
    }

    @Test
    @DisplayName("3010 INVALID_TYPE — type='xxx' 抛 BizException(3010)")
    void invalidType() {
        var req = buildReq("xxx", null, UUID.randomUUID().toString(), null);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3010));
    }

    @Test
    @DisplayName("3010 — 空 type 同样触发 3010")
    void emptyType() {
        var req = buildReq("", null, UUID.randomUUID().toString(), null);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3010));
    }

    @Test
    @DisplayName("3011 CATEGORY_REQUIRED — expense 缺 categoryId 抛 3011")
    void expenseMissingCategory() {
        var req = buildReq("expense", null, UUID.randomUUID().toString(), null);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3011));
    }

    @Test
    @DisplayName("3011 — income 缺 categoryId 同样抛 3011")
    void incomeMissingCategory() {
        var req = buildReq("income", null, UUID.randomUUID().toString(), null);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3011));
    }

    @Test
    @DisplayName("3012 CATEGORY_TYPE_MISMATCH — expense + income 分类抛 3012")
    void categoryTypeMismatch() {
        String catUuid = UUID.randomUUID().toString();
        Category cat = Category.builder()
            .id(300L).uuid(catUuid).name("工资").type("income").build();
        when(categoryMapper.selectOne(any())).thenReturn(cat);

        var req = buildReq("expense", catUuid, UUID.randomUUID().toString(), null);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3012));
    }

    @Test
    @DisplayName("3013 TO_ACCOUNT_REQUIRED — transfer 缺 toAccountId 抛 3013")
    void transferMissingToAccount() {
        var req = buildReq("transfer", null, UUID.randomUUID().toString(), null);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3013));
    }

    @Test
    @DisplayName("3014 SAME_ACCOUNT_TRANSFER — 转出=转入抛 3014")
    void sameAccountTransfer() {
        String sameUuid = UUID.randomUUID().toString();
        var req = buildReq("transfer", null, sameUuid, sameUuid);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3014));
    }

    @Test
    @DisplayName("3015 INVALID_RECORD_DATE — '2026/09/04' 非 YYYY-MM-DD 抛 3015")
    void invalidRecordDate() {
        // 必须先提供一个合法的 expense category,否则会先触发 3011 而非 3015
        String catUuid = UUID.randomUUID().toString();
        Category cat = Category.builder()
            .id(300L).uuid(catUuid).name("餐饮").type("expense").build();
        when(categoryMapper.selectOne(any())).thenReturn(cat);

        var req = new CreateRecordRequest(
            "expense",
            catUuid,
            UUID.randomUUID().toString(),
            null,
            BigDecimal.TEN,
            "2026/09/04",
            "note",
            "client-1",
            null
        );
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3015));
    }

    @Test
    @DisplayName("3016 ACCOUNT_NOT_FOUND — accountMapper 返 null 抛 3016")
    void accountNotFound() {
        when(accountMapper.selectOne(any())).thenReturn(null);
        var req = buildReq("expense", null, UUID.randomUUID().toString(), null);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3016));
    }

    @Test
    @DisplayName("3017 ACCOUNT_NOT_IN_BOOK — account.bookId != book.id 抛 3017")
    void accountNotInBook() {
        Account wrongBookAccount = Account.builder()
            .id(201L).uuid(UUID.randomUUID().toString())
            .userId(1L).bookId(999L) // 不同 book
            .name("其他账本账户")
            .currency("CNY")
            .build();
        when(accountMapper.selectOne(any())).thenReturn(wrongBookAccount);

        var req = buildReq("expense", null, UUID.randomUUID().toString(), null);
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3017));
    }

    @Test
    @DisplayName("happy path — expense 合法入参跑完 create,RecordResponse 字段一致")
    void expenseHappyPath() {
        String catUuid = UUID.randomUUID().toString();
        Category cat = Category.builder()
            .id(300L).uuid(catUuid).name("餐饮").type("expense").build();
        when(categoryMapper.selectOne(any())).thenReturn(cat);
        when(recordMapper.insert(any(Record.class))).thenReturn(1);

        var req = buildReq("expense", catUuid, UUID.randomUUID().toString(), null);
        var resp = service.create(1L, req);

        assertThat(resp).isNotNull();
        assertThat(resp.type()).isEqualTo("expense");
        assertThat(resp.amount()).isEqualByComparingTo(BigDecimal.TEN);
        assertThat(resp.categoryId()).isEqualTo(catUuid);
        assertThat(resp.currency()).isEqualTo("CNY");
        assertThat(resp.recordDate()).isNotNull();
    }

    // ---- helpers ----

    private CreateRecordRequest buildReq(String type, String categoryUuid,
                                          String accountUuid, String toAccountUuid) {
        return new CreateRecordRequest(
            type,
            categoryUuid,
            accountUuid,
            toAccountUuid,
            BigDecimal.TEN,
            "2026-09-04",
            "note",
            "client-" + UUID.randomUUID(),
            null
        );
    }
}