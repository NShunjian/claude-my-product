package com.qingzhang.records;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.books.BooksService;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.records.dto.CreateRecordRequest;
import com.qingzhang.records.dto.RecordResponse;
import com.qingzhang.records.dto.UpdateRecordRequest;
import com.qingzhang.records.entity.Record;
import com.qingzhang.records.mapper.RecordMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.time.YearMonth;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * 账目域业务。
 *
 * 错误码:30xx 账目域(子码):
 *   3001  RECORD_NOT_FOUND
 *   3010  INVALID_TYPE
 *   3011  CATEGORY_REQUIRED / INVALID
 *   3012  CATEGORY_TYPE_MISMATCH
 *   3013  TO_ACCOUNT_REQUIRED
 *   3014  SAME_ACCOUNT_TRANSFER
 *   3015  INVALID_RECORD_DATE
 *   3016  ACCOUNT_NOT_FOUND
 *   3017  ACCOUNT_NOT_IN_BOOK
 *
 * 设计要点:
 *   1. 真实账户余额走 v_account_balance 视图实时算,本服务不维护 current_balance 冗余。
 *   2. 转账联动由视图自然处理 —— account_id 端减、to_account_id 端加。
 *   3. V1.1:账目必须挂在 book_id 上;account/toAccount 必须与 book 匹配(spec §6.2)。
 */
@Service
public class RecordsService {

    private static final int CODE_RECORD_NOT_FOUND      = 3001;
    private static final int CODE_INVALID_TYPE           = 3010;
    private static final int CODE_CATEGORY_REQUIRED      = 3011;
    private static final int CODE_CATEGORY_TYPE_MISMATCH = 3012;
    private static final int CODE_TO_ACCOUNT_REQUIRED    = 3013;
    private static final int CODE_SAME_ACCOUNT_TRANSFER  = 3014;
    private static final int CODE_INVALID_RECORD_DATE    = 3015;
    private static final int CODE_ACCOUNT_NOT_FOUND      = 3016;
    private static final int CODE_ACCOUNT_NOT_IN_BOOK    = 3017;

    private final RecordMapper recordMapper;
    private final CategoryMapper categoryMapper;
    private final AccountMapper accountMapper;
    private final BookMapper bookMapper;
    private final BooksService booksService;

    public RecordsService(RecordMapper recordMapper,
                          CategoryMapper categoryMapper,
                          AccountMapper accountMapper,
                          BookMapper bookMapper,
                          BooksService booksService) {
        this.recordMapper = recordMapper;
        this.categoryMapper = categoryMapper;
        this.accountMapper = accountMapper;
        this.bookMapper = bookMapper;
        this.booksService = booksService;
    }

    // ===== 列表 =====

    public List<RecordResponse> list(long userId, Map<String, String> filters) {
        var q = Wrappers.<Record>lambdaQuery()
                .eq(Record::getUserId, userId)
                .orderByDesc(Record::getRecordDate)
                .orderByDesc(Record::getId);

        String month      = filters.get("month");
        String from       = filters.get("from");
        String to         = filters.get("to");
        String type       = filters.get("type");
        String categoryId = filters.get("categoryId");
        String accountId  = filters.get("accountId");
        String bookUuid   = filters.get("bookId");

        // bookId 过滤:空 → 用户所有账本;非空 → 必须可访问
        if (bookUuid != null && !bookUuid.isBlank()) {
            Long bid = booksService.mustAccessibleBook(userId, bookUuid).getId();
            q.eq(Record::getBookId, bid);
        }

        if (month != null && !month.isBlank()) {
            LocalDate[] range = monthRange(month);
            q.between(Record::getRecordDate, range[0], range[1]);
        }
        if (from != null && !from.isBlank()) {
            q.ge(Record::getRecordDate, LocalDate.parse(from));
        }
        if (to != null && !to.isBlank()) {
            q.le(Record::getRecordDate, LocalDate.parse(to));
        }
        if (type != null && !type.isBlank()) {
            q.eq(Record::getType, type);
        }
        if (categoryId != null && !categoryId.isBlank()) {
            Long catId = resolveCategoryId(categoryId);
            if (catId == null) return List.of();
            q.eq(Record::getCategoryId, catId);
        }
        if (accountId != null && !accountId.isBlank()) {
            Long accId = resolveAccountId(userId, accountId);
            if (accId == null) return List.of();
            q.and(w -> w.eq(Record::getAccountId, accId).or().eq(Record::getToAccountId, accId));
        }

        List<Record> records = recordMapper.selectList(q);
        return toResponses(userId, records);
    }

    // ===== 创建 =====

    @Transactional(rollbackFor = Exception.class)
    public RecordResponse create(long userId, CreateRecordRequest req) {
        String type = req.type();
        if (!"expense".equals(type) && !"income".equals(type) && !"transfer".equals(type)) {
            throw new BizException(CODE_INVALID_TYPE, "type 必须是 expense / income / transfer");
        }

        // 解析账本:bookId 空 → 用户默认账本;非空 → 必须可访问
        Book book = resolveBookForCreate(userId, req.bookId());

        // 校验账户归属该账本(V1.1)
        Account account = mustAccount(userId, req.accountId());
        assertAccountInBook(account, book, "accountId");
        String accountUuid = account.getUuid();

        String categoryUuid = null;
        Long categoryId = null;
        if ("expense".equals(type) || "income".equals(type)) {
            if (req.categoryId() == null || req.categoryId().isBlank()) {
                throw new BizException(CODE_CATEGORY_REQUIRED, "expense / income 必须指定 categoryId");
            }
            Category cat = mustCategory(userId, req.categoryId(), type);
            categoryUuid = cat.getUuid();
            categoryId = cat.getId();
        }

        String toAccountUuid = null;
        Long toAccountId = null;
        if ("transfer".equals(type)) {
            if (req.toAccountId() == null || req.toAccountId().isBlank()) {
                throw new BizException(CODE_TO_ACCOUNT_REQUIRED, "transfer 必须指定 toAccountId");
            }
            if (req.toAccountId().equals(req.accountId())) {
                throw new BizException(CODE_SAME_ACCOUNT_TRANSFER, "转出与转入账户不可相同");
            }
            Account to = mustAccount(userId, req.toAccountId());
            assertAccountInBook(to, book, "toAccountId");
            toAccountUuid = to.getUuid();
            toAccountId = to.getId();
        }

        LocalDate recordDate = parseRecordDate(req.recordDate());
        Instant now = Instant.now();

        Record r = Record.builder()
                .uuid(UUID.randomUUID().toString())
                .userId(userId)
                .bookId(book.getId())
                .type(type)
                .categoryId(categoryId)
                .accountId(account.getId())
                .toAccountId(toAccountId)
                .amount(req.amount())
                .currency(book.getCurrency())
                .note(req.note())
                .recordDate(recordDate)
                .source("manual")
                .clientId(req.clientId())
                .createdAt(now)
                .updatedAt(now)
                .build();
        recordMapper.insert(r);
        return new RecordResponse(
                r.getUuid(), r.getType(), categoryUuid, accountUuid, toAccountUuid,
                r.getAmount(), r.getCurrency(), r.getNote(), r.getRecordDate(),
                r.getSource(), r.getClientId(), r.getCreatedAt(), r.getUpdatedAt()
        );
    }

    // ===== 修改 =====

    @Transactional(rollbackFor = Exception.class)
    public RecordResponse update(long userId, String uuid, UpdateRecordRequest req) {
        Record r = mustOwned(userId, uuid);

        String categoryUuid = null; // null 表示本字段未变化
        if (req.categoryId() != null) {
            if (req.categoryId().isBlank()) {
                r.setCategoryId(null);
            } else if ("transfer".equals(r.getType())) {
                throw new BizException(CODE_CATEGORY_REQUIRED, "transfer 类型不允许关联分类");
            } else {
                Category cat = mustCategory(userId, req.categoryId(), r.getType());
                r.setCategoryId(cat.getId());
                categoryUuid = cat.getUuid();
            }
        }

        String accountUuid = null;
        if (req.accountId() != null && !req.accountId().isBlank()) {
            Account a = mustAccount(userId, req.accountId());
            // 校验新账户属于当前账目所在账本
            Book b = bookMapper.selectById(r.getBookId());
            if (b == null) throw new BizException(ErrorCode.INTERNAL, "账目关联的账本不存在");
            assertAccountInBook(a, b, "accountId");
            r.setAccountId(a.getId());
            accountUuid = a.getUuid();
        }

        String toAccountUuid = null;
        if (req.toAccountId() != null) {
            if (req.toAccountId().isBlank()) {
                r.setToAccountId(null);
            } else {
                if (!"transfer".equals(r.getType())) {
                    throw new BizException(CODE_TO_ACCOUNT_REQUIRED, "非 transfer 类型不允许设置 toAccountId");
                }
                if (req.accountId() != null && req.toAccountId().equals(req.accountId())) {
                    throw new BizException(CODE_SAME_ACCOUNT_TRANSFER, "转出与转入账户不可相同");
                }
                Account to = mustAccount(userId, req.toAccountId());
                Book b = bookMapper.selectById(r.getBookId());
                if (b == null) throw new BizException(ErrorCode.INTERNAL, "账目关联的账本不存在");
                assertAccountInBook(to, b, "toAccountId");
                r.setToAccountId(to.getId());
                toAccountUuid = to.getUuid();
            }
        }

        if (req.amount() != null) r.setAmount(req.amount());
        if (req.recordDate() != null && !req.recordDate().isBlank()) {
            r.setRecordDate(parseRecordDate(req.recordDate()));
        }
        if (req.note() != null) r.setNote(req.note().isBlank() ? null : req.note());

        r.setUpdatedAt(Instant.now());
        recordMapper.updateById(r);

        // 把没变化 uuid 补回来(读 DB 当前值)
        return toResponses(userId, List.of(r)).get(0);
    }

    // ===== 删除 =====

    @Transactional(rollbackFor = Exception.class)
    public void delete(long userId, String uuid) {
        Record r = mustOwned(userId, uuid);
        recordMapper.deleteById(r.getId());
    }

    // ===== 内部工具 =====

    private Record mustOwned(long userId, String uuid) {
        Record r = recordMapper.selectOne(Wrappers.<Record>lambdaQuery()
                .eq(Record::getUuid, uuid)
                .eq(Record::getUserId, userId));
        if (r == null) throw new BizException(CODE_RECORD_NOT_FOUND, "账目不存在");
        return r;
    }

    private Account mustAccount(long userId, String uuid) {
        Account a = accountMapper.selectOne(Wrappers.<Account>lambdaQuery()
                .eq(Account::getUuid, uuid)
                .eq(Account::getUserId, userId)
                .eq(Account::getIsArchived, (byte) 0));
        if (a == null) throw new BizException(CODE_ACCOUNT_NOT_FOUND, "账户不存在或已归档: " + uuid);
        return a;
    }

    private Long resolveAccountId(long userId, String uuid) {
        Account a = accountMapper.selectOne(Wrappers.<Account>lambdaQuery()
                .eq(Account::getUuid, uuid)
                .eq(Account::getUserId, userId));
        return a == null ? null : a.getId();
    }

    private Long resolveCategoryId(String uuid) {
        Category c = categoryMapper.selectOne(Wrappers.<Category>lambdaQuery()
                .eq(Category::getUuid, uuid)
                .eq(Category::getIsActive, (byte) 1));
        return c == null ? null : c.getId();
    }

    private Category mustCategory(long userId, String uuid, String expectedType) {
        Category c = categoryMapper.selectOne(Wrappers.<Category>lambdaQuery()
                .eq(Category::getUuid, uuid)
                .eq(Category::getIsActive, (byte) 1)
                .and(w -> w.isNull(Category::getUserId).or().eq(Category::getUserId, userId)));
        if (c == null) throw new BizException(CODE_CATEGORY_REQUIRED, "分类不存在或已停用: " + uuid);
        if (!c.getType().equals(expectedType)) {
            throw new BizException(CODE_CATEGORY_TYPE_MISMATCH,
                    "分类类型(" + c.getType() + ")与账目类型(" + expectedType + ")不匹配");
        }
        return c;
    }

    /** V1.1:账户必须挂在当前账目所在账本下。 */
    private void assertAccountInBook(Account a, Book book, String field) {
        // 允许 book_id=null(账户未挂账本,默认归个人)与 book.id 匹配都通过。
        if (a.getBookId() != null && !a.getBookId().equals(book.getId())) {
            throw new BizException(CODE_ACCOUNT_NOT_IN_BOOK,
                    field + " 关联的账户不属于该账本: " + a.getUuid());
        }
    }

    /** 创建账目时决定归属账本:空 → 用户默认账本;非空 → 必须可访问。 */
    private Book resolveBookForCreate(long userId, String bookUuid) {
        if (bookUuid == null || bookUuid.isBlank()) {
            return booksService.defaultBookOf(userId);
        }
        return booksService.mustAccessibleBook(userId, bookUuid);
    }

    private static LocalDate parseRecordDate(String s) {
        try {
            return LocalDate.parse(s, DateTimeFormatter.ISO_LOCAL_DATE);
        } catch (DateTimeParseException ex) {
            throw new BizException(CODE_INVALID_RECORD_DATE, "recordDate 必须是 YYYY-MM-DD 格式");
        }
    }

    private static LocalDate[] monthRange(String month) {
        try {
            YearMonth ym = YearMonth.parse(month);
            return new LocalDate[] { ym.atDay(1), ym.atEndOfMonth() };
        } catch (DateTimeParseException ex) {
            throw new BizException(CODE_INVALID_RECORD_DATE, "month 必须是 YYYY-MM 格式");
        }
    }

    /**
     * 把 records 转成 RecordResponse,把 id 反查成 uuid。
     * 一次性把当前用户涉及的 accounts/categories 全部拉出来,O(1) map 查,避免 N+1。
     */
    private List<RecordResponse> toResponses(long userId, List<Record> records) {
        if (records.isEmpty()) return List.of();

        // 收集涉及的 id
        java.util.Set<Long> accIds = new java.util.HashSet<>();
        java.util.Set<Long> catIds = new java.util.HashSet<>();
        for (Record r : records) {
            if (r.getAccountId() != null)    accIds.add(r.getAccountId());
            if (r.getToAccountId() != null)  accIds.add(r.getToAccountId());
            if (r.getCategoryId() != null)   catIds.add(r.getCategoryId());
        }

        Map<Long, String> accUuids = accIds.isEmpty()
                ? Map.of()
                : accountMapper.selectBatchIds(accIds).stream()
                        .filter(a -> userId == 0L || a.getUserId() == null || a.getUserId() == userId)
                        .collect(Collectors.toMap(Account::getId, Account::getUuid, (a, b) -> a, HashMap::new));

        Map<Long, String> catUuids = catIds.isEmpty()
                ? Map.of()
                : categoryMapper.selectBatchIds(catIds).stream()
                        .filter(c -> c.getUserId() == null || c.getUserId() == userId)
                        .collect(Collectors.toMap(Category::getId, Category::getUuid, (a, b) -> a, HashMap::new));

        return records.stream().map(r -> new RecordResponse(
                r.getUuid(),
                r.getType(),
                r.getCategoryId() == null ? null : catUuids.get(r.getCategoryId()),
                r.getAccountId()  == null ? null : accUuids.get(r.getAccountId()),
                r.getToAccountId() == null ? null : accUuids.get(r.getToAccountId()),
                r.getAmount(),
                r.getCurrency(),
                r.getNote(),
                r.getRecordDate(),
                r.getSource(),
                r.getClientId(),
                r.getCreatedAt(),
                r.getUpdatedAt()
        )).toList();
    }
}
