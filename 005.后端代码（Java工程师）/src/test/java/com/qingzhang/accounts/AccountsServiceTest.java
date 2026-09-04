package com.qingzhang.accounts;

import com.baomidou.mybatisplus.core.metadata.TableInfoHelper;
import com.qingzhang.accounts.dto.AccountResponse;
import com.qingzhang.accounts.dto.CreateAccountRequest;
import com.qingzhang.accounts.dto.UpdateAccountRequest;
import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.entity.AccountBalance;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.books.BooksService;
import com.qingzhang.books.entity.Book;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.common.BizException;
import org.apache.ibatis.builder.MapperBuilderAssistant;
import org.apache.ibatis.session.Configuration;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 005 Java 后端 — AccountsService 账户 CRUD 业务测试
 *
 * 覆盖目标(005-java-backend.md §6.4):
 *   - list:不过滤 → 全部;按 bookId 过滤
 *   - get:找不到 → 3001 ACCOUNT_NOT_FOUND
 *   - create:成功,is_default 单选(置 true 时把其他 default 卸掉)
 *   - create:不传 bookId → 走用户默认账本
 *   - update:isDefault=true → 重置其他账户 default
 *   - delete:删除 default 账户 → 3002 ACCOUNT_HAS_RECORDS
 *
 * 工具:JUnit 5 + Mockito + AssertJ
 */
class AccountsServiceTest {

    private AccountMapper accountMapper;
    private BooksService booksService;
    private AccountsService service;

    private static final long USER_ID = 100L;
    private static final long BOOK_ID = 1000L;
    private static final long OTHER_BOOK_ID = 1001L;

    @BeforeAll
    static void initMybatisPlusLambdaCache() {
        // 单元测试不走 SpringBoot 启动,MyBatis-Plus 不会自动扫描 entity。
        // 这里手动初始化 lambda 缓存,让 Wrappers.<Account>lambdaUpdate() 等能用。
        Configuration cfg = new Configuration();
        MapperBuilderAssistant assistant = new MapperBuilderAssistant(cfg, "test-resources");
        TableInfoHelper.initTableInfo(assistant, Account.class);
        TableInfoHelper.initTableInfo(assistant, Category.class);
        TableInfoHelper.initTableInfo(assistant, Book.class);
    }

    @BeforeEach
    void setUp() {
        accountMapper = mock(AccountMapper.class);
        booksService = mock(BooksService.class);
        service = new AccountsService(accountMapper, booksService);

        Book defaultBook = Book.builder()
            .id(BOOK_ID).uuid(UUID.randomUUID().toString())
            .ownerId(USER_ID).name("个人账本").type("personal").currency("CNY").build();
        when(booksService.defaultBookOf(USER_ID)).thenReturn(defaultBook);
        when(booksService.mustAccessibleBook(anyLong(), any())).thenReturn(defaultBook);

        // 模拟 MyBatis-Plus 自增主键回写 — 让 service.create() 之后的 findBalanceById 能查到
        when(accountMapper.insert(any(Account.class))).thenAnswer(inv -> {
            Account a = inv.getArgument(0);
            if (a.getId() == null) a.setId(System.nanoTime() & 0xfffff);
            return 1;
        });
    }

    @Test
    @DisplayName("list — 不传 bookId → 返回用户全部账户,按 sortOrder 升序")
    void listAllAccounts() {
        Account a = makeAccount(11L, "微信支付", true, 0);
        Account b = makeAccount(12L, "支付宝", false, 1);
        when(accountMapper.selectList(any())).thenReturn(List.of(a, b));
        when(accountMapper.findBalanceById(anyLong(), anyLong()))
            .thenReturn(toBalance(a)).thenReturn(toBalance(b));

        List<AccountResponse> list = service.list(USER_ID, null);

        assertThat(list).hasSize(2);
        assertThat(list.get(0).name()).isEqualTo("微信支付");
        assertThat(list.get(0).isDefault()).isTrue();
        assertThat(list.get(1).name()).isEqualTo("支付宝");
        assertThat(list.get(1).isDefault()).isFalse();
    }

    @Test
    @DisplayName("list — 传 bookId → 走 mustAccessibleBook 解析后再过滤")
    void listFilteredByBook() {
        String bookUuid = UUID.randomUUID().toString();
        Book filteredBook = Book.builder()
            .id(OTHER_BOOK_ID).uuid(bookUuid).ownerId(USER_ID).name("家庭账本").build();
        when(booksService.mustAccessibleBook(USER_ID, bookUuid)).thenReturn(filteredBook);

        Account a = makeAccount(33L, "家庭现金", false, 0);
        a.setBookId(OTHER_BOOK_ID);
        when(accountMapper.selectList(any())).thenReturn(List.of(a));
        when(accountMapper.findBalanceById(anyLong(), anyLong())).thenReturn(toBalance(a));

        List<AccountResponse> list = service.list(USER_ID, bookUuid);

        assertThat(list).hasSize(1);
        assertThat(list.get(0).name()).isEqualTo("家庭现金");
        verify(booksService).mustAccessibleBook(USER_ID, bookUuid);
    }

    @Test
    @DisplayName("get — 账户不属于当前用户 → 抛 3001")
    void getNotOwned() {
        when(accountMapper.selectOne(any())).thenReturn(null);

        assertThatThrownBy(() -> service.get(USER_ID, "ghost-uuid"))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3001));
    }

    @Test
    @DisplayName("get — happy path → 返回 AccountResponse 含余额")
    void getHappyPath() {
        Account a = makeAccount(50L, "银行卡", false, 1);
        a.setInitialBalance(new BigDecimal("1000.00"));
        when(accountMapper.selectOne(any())).thenReturn(a);
        AccountBalance bal = toBalance(a);
        bal.setBalance(new BigDecimal("850.50"));
        when(accountMapper.findBalanceById(a.getId(), USER_ID)).thenReturn(bal);

        AccountResponse resp = service.get(USER_ID, a.getUuid());

        assertThat(resp).isNotNull();
        assertThat(resp.name()).isEqualTo("银行卡");
        assertThat(resp.balance()).isEqualByComparingTo(new BigDecimal("850.50"));
        assertThat(resp.currency()).isEqualTo("CNY");
        assertThat(resp.isDefault()).isFalse();
    }

    @Test
    @DisplayName("create — isDefault=true → 调用 update 把同用户其他 default 卸掉,然后 insert 新账户")
    void createWithDefaultFlag() {
        CreateAccountRequest req = new CreateAccountRequest(
            "新默认账户", "wallet", "💳",
            BigDecimal.ZERO, "CNY", true, 5, "新账户", null
        );
        when(accountMapper.findBalanceById(anyLong(), anyLong()))
            .thenAnswer(inv -> {
                long id = inv.getArgument(0);
                Account inserted = Account.builder()
                    .id(id).userId(USER_ID).bookId(BOOK_ID)
                    .name("新默认账户").type("wallet").currency("CNY")
                    .initialBalance(BigDecimal.ZERO).currentBalance(BigDecimal.ZERO)
                    .isDefault((byte) 1).sortOrder(5).build();
                return toBalance(inserted);
            });

        AccountResponse resp = service.create(USER_ID, req);

        assertThat(resp).isNotNull();
        assertThat(resp.name()).isEqualTo("新默认账户");
        assertThat(resp.isDefault()).isTrue();
        // 关键断言:置 is_default 时一定要先把同用户其他 default 全卸掉
        verify(accountMapper, times(1)).update(any(), any());
        verify(accountMapper, times(1)).insert(any(Account.class));
    }

    @Test
    @DisplayName("create — 不传 bookId → 走用户的默认账本")
    void createWithDefaultBook() {
        CreateAccountRequest req = new CreateAccountRequest(
            "现金账户", "cash", "💵",
            new BigDecimal("200.00"), "CNY", false, 0, null, null
        );
        when(accountMapper.findBalanceById(anyLong(), anyLong()))
            .thenAnswer(inv -> {
                long id = inv.getArgument(0);
                Account inserted = Account.builder()
                    .id(id).userId(USER_ID).bookId(BOOK_ID)
                    .name("现金账户").type("cash").currency("CNY")
                    .initialBalance(new BigDecimal("200.00")).currentBalance(new BigDecimal("200.00"))
                    .isDefault((byte) 0).build();
                return toBalance(inserted);
            });

        AccountResponse resp = service.create(USER_ID, req);

        assertThat(resp.name()).isEqualTo("现金账户");
        assertThat(resp.initialBalance()).isEqualByComparingTo(new BigDecimal("200.00"));
        verify(booksService, times(1)).defaultBookOf(USER_ID);
        verify(booksService, never()).mustAccessibleBook(anyLong(), any());
    }

    @Test
    @DisplayName("update — isDefault=true → updateById 写入新默认,同时把其他 default 卸掉")
    void updateSettingDefault() {
        Account a = makeAccount(60L, "原默认", true, 0);
        when(accountMapper.selectOne(any())).thenReturn(a);
        when(accountMapper.updateById(any(Account.class))).thenReturn(1);
        when(accountMapper.findBalanceById(anyLong(), anyLong())).thenReturn(toBalance(a));

        UpdateAccountRequest req = new UpdateAccountRequest(
            null, null, null, null, null, true, null, null, null  // bookId 末尾位(V1.1 锁定,忽略)
        );
        AccountResponse resp = service.update(USER_ID, a.getUuid(), req);

        assertThat(resp).isNotNull();
        verify(accountMapper, times(1)).update(any(), any());
        verify(accountMapper, times(1)).updateById(any(Account.class));
    }

    @Test
    @DisplayName("delete — 默认账户(isDefault=1)→ 抛 3002,不能删")
    void deleteDefaultAccount() {
        Account defaultAcc = makeAccount(70L, "默认账户", true, 0);
        when(accountMapper.selectOne(any())).thenReturn(defaultAcc);

        assertThatThrownBy(() -> service.delete(USER_ID, defaultAcc.getUuid()))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(3002));
        verify(accountMapper, never()).deleteById(anyLong());
    }

    @Test
    @DisplayName("delete — 非默认账户 → 走 deleteById 硬删成功")
    void deleteNonDefaultAccount() {
        Account acc = makeAccount(80L, "普通账户", false, 1);
        when(accountMapper.selectOne(any())).thenReturn(acc);
        when(accountMapper.deleteById(acc.getId())).thenReturn(1);

        service.delete(USER_ID, acc.getUuid());

        verify(accountMapper, times(1)).deleteById(acc.getId());
    }

    // ---- helpers ----

    private Account makeAccount(long id, String name, boolean isDefault, int sortOrder) {
        return Account.builder()
            .id(id).uuid(UUID.randomUUID().toString())
            .userId(USER_ID).bookId(BOOK_ID)
            .name(name).type("wallet").icon("💳")
            .initialBalance(BigDecimal.ZERO).currentBalance(BigDecimal.ZERO)
            .currency("CNY")
            .isDefault((byte) (isDefault ? 1 : 0))
            .isArchived((byte) 0)
            .sortOrder(sortOrder)
            .createdAt(Instant.now()).updatedAt(Instant.now())
            .build();
    }

    private AccountBalance toBalance(Account a) {
        return AccountBalance.builder()
            .id(a.getId()).uuid(a.getUuid())
            .userId(a.getUserId()).bookId(a.getBookId())
            .name(a.getName()).type(a.getType()).icon(a.getIcon())
            .initialBalance(a.getInitialBalance())
            .balance(a.getCurrentBalance())
            .currency(a.getCurrency())
            .isDefault(a.getIsDefault())
            .isArchived(a.getIsArchived())
            .sortOrder(a.getSortOrder())
            .note(a.getNote())
            .createdAt(a.getCreatedAt())
            .build();
    }
}