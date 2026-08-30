package com.qingzhang.admin.records;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.qingzhang.admin.dto.AdminRecordListItem;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.categories.entity.Category;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.records.entity.Record;
import com.qingzhang.records.mapper.RecordMapper;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class AdminRecordService {

    private final RecordMapper recordMapper;
    private final UserMapper userMapper;
    private final BookMapper bookMapper;
    private final CategoryMapper categoryMapper;

    public AdminRecordService(RecordMapper recordMapper,
                               UserMapper userMapper,
                               BookMapper bookMapper,
                               CategoryMapper categoryMapper) {
        this.recordMapper = recordMapper;
        this.userMapper = userMapper;
        this.bookMapper = bookMapper;
        this.categoryMapper = categoryMapper;
    }

    public Page<AdminRecordListItem> list(Long userId,
                                          String bookUuid,
                                          String type,
                                          LocalDate dateFrom,
                                          LocalDate dateTo,
                                          long page,
                                          long size) {
        long p = Math.max(1, page);
        long s = Math.min(Math.max(1, size), 100);

        QueryWrapper<Record> q = new QueryWrapper<>();
        if (userId != null) q.eq("user_id", userId);
        if (bookUuid != null && !bookUuid.isBlank()) q.eq("book_id",
                bookIdFor(bookUuid.trim()));  // resolved below in helper
        if (type != null && !type.isBlank()) q.eq("type", type.trim());
        if (dateFrom != null) q.ge("record_date", dateFrom);
        if (dateTo != null) q.le("record_date", dateTo);
        q.orderByDesc("record_date").orderByDesc("id");

        IPage<Record> mp = recordMapper.selectPage(
                new com.baomidou.mybatisplus.extension.plugins.pagination.Page<>(p, s), q);
        long total = mp.getTotal();

        List<Record> rows = mp.getRecords();
        // 4 个 in-memory 拼装 —— 详情见 helper
        Map<Long, String> userById = batchUsers(rows.stream().map(Record::getUserId).collect(Collectors.toSet()));
        Map<Long, Book> bookById = batchBooks(rows.stream().map(Record::getBookId).collect(Collectors.toSet()));
        Map<Long, String> catById = batchCategories(rows.stream().map(Record::getCategoryId).collect(Collectors.toSet()));
        // account name 需要 accounts 表 —— v1 留 null,不预聚合

        List<AdminRecordListItem> items = rows.stream().map(r -> {
            Book b = bookById.get(r.getBookId());
            return new AdminRecordListItem(
                    r.getUuid(),
                    r.getType(),
                    r.getAmount(),
                    r.getCurrency(),
                    r.getNote(),
                    r.getRecordDate(),
                    r.getSource(),
                    r.getUserId() == null ? 0L : r.getUserId(),
                    userById.getOrDefault(r.getUserId(), "unknown"),
                    b != null ? b.getUuid() : null,
                    b != null ? b.getName() : null,
                    catById.get(r.getCategoryId()),
                    null,  // accountName —— v1 不查 accounts 表
                    r.getCreatedAt()
            );
        }).collect(Collectors.toList());

        return new Page<>(items, total, s, p);
    }

    private long bookIdFor(String bookUuid) {
        Book b = bookMapper.selectOne(new QueryWrapper<Book>().eq("uuid", bookUuid));
        if (b == null) return -1L;  // 查不到 → 命中不到任何 record
        return b.getId();
    }

    private Map<Long, String> batchUsers(Set<Long> ids) {
        if (ids.isEmpty()) return Map.of();
        Map<Long, String> m = new HashMap<>();
        for (User u : userMapper.selectBatchIds(ids)) m.put(u.getId(), u.getUsername());
        return m;
    }

    private Map<Long, Book> batchBooks(Set<Long> ids) {
        if (ids.isEmpty()) return Map.of();
        Map<Long, Book> m = new HashMap<>();
        for (Book b : bookMapper.selectBatchIds(ids)) m.put(b.getId(), b);
        return m;
    }

    private Map<Long, String> batchCategories(Set<Long> ids) {
        if (ids.isEmpty()) return Map.of();
        Map<Long, String> m = new HashMap<>();
        for (Category c : categoryMapper.selectBatchIds(ids)) m.put(c.getId(), c.getName());
        return m;
    }
}
