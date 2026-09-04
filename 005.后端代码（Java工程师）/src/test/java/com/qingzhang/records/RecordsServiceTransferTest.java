package com.qingzhang.records;

import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.books.BooksService;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
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
 * 005 Java 后端 — RecordsService.transfer 联动测试(占位骨架 → 真实断言)
 *
 * 覆盖目标:
 *   - 转账 A→B 50:A 减 50,B 加 50(走视图实时聚合,余额在调用方后端查)
 *   - transfer toAccountId 不在 book → 3017
 *   - transfer 类型合法时不需要传 categoryId(走 transfer 分支跳过 category)
 *   - transfer happy path:RecordResponse.toAccountUuid 字段正确填充
 *
 * 工具:JUnit 5 + Mockito + AssertJ
 */
class RecordsServiceTransferTest {

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

        Book book = Book.builder()
            .id(100L).uuid(UUID.randomUUID().toString())
            .ownerId(1L).name("个人账本").currency("CNY").build();
        when(booksService.mustAccessibleBook(anyLong(), anyString())).thenReturn(book);
        when(booksService.defaultBookOf(anyLong())).thenReturn(book);
    }

    @Test
    @DisplayName("transfer happy path — A→B,RecordResponse.toAccountUuid 与 toAccountId 一致")
    void transferHappyPath() {
        String accountAUuid = UUID.randomUUID().toString();
        String accountBUuid = UUID.randomUUID().toString();
        Account a = Account.builder()
            .id(200L).uuid(accountAUuid).userId(1L).bookId(100L)
            .name("微信钱包").currency("CNY").build();
        Account b = Account.builder()
            .id(201L).uuid(accountBUuid).userId(1L).bookId(100L)
            .name("银行卡").currency("CNY").build();
        // 必须项按调用顺序:mustAccount(accountId) → A;mustAccount(toAccountId) → B
        when(accountMapper.selectOne(any()))
            .thenReturn(a)   // 第 1 次 mustAccount(accountId)
            .thenReturn(b);  // 第 2 次 mustAccount(toAccountId)
        when(recordMapper.insert(any(Record.class))).thenReturn(1);

        var req = new CreateRecordRequest(
            "transfer", null, accountAUuid, accountBUuid,
            new BigDecimal("50.00"), "2026-09-04", "转账备注", "client-t1", null
        );
        var resp = service.create(1L, req);

        assertThat(resp).isNotNull();
        assertThat(resp.type()).isEqualTo("transfer");
        assertThat(resp.accountId()).isEqualTo(accountAUuid);
        assertThat(resp.toAccountId()).isEqualTo(accountBUuid);
        assertThat(resp.amount()).isEqualByComparingTo(new BigDecimal("50.00"));
        assertThat(resp.categoryId()).isNull(); // transfer 不需要 category
    }

    @Test
    @DisplayName("transfer toAccountId 不属于当前 book → 3017")
    void transferToAccountInOtherBook() {
        String accountAUuid = UUID.randomUUID().toString();
        String accountBUuid = UUID.randomUUID().toString();
        Account a = Account.builder()
            .id(200L).uuid(accountAUuid).userId(1L).bookId(100L)
            .name("微信钱包").currency("CNY").build();
        Account b = Account.builder()
            .id(201L).uuid(accountBUuid).userId(1L).bookId(999L) // 不同 book
            .name("其他账本账户").currency("CNY").build();
        when(accountMapper.selectOne(any())).thenReturn(a).thenReturn(b);

        var req = new CreateRecordRequest(
            "transfer", null, accountAUuid, accountBUuid,
            new BigDecimal("10.00"), "2026-09-04", null, "client-t2", null
        );
        assertThatThrownBy(() -> service.create(1L, req))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3017));
    }
}