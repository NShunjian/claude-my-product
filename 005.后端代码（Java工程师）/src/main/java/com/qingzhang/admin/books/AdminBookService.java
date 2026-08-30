package com.qingzhang.admin.books;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.qingzhang.admin.dto.AdminBookListItem;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.springframework.stereotype.Service;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Admin view:所有账本(跨用户)。只读 v1。
 *
 * ponytail:不做 JOIN;批查 User 后 in-memory map 拼装 username。page size ≤ 100 时
 * 总查询数 = 1 books + 1 users,跟 v2 视图持平。
 */
@Service
public class AdminBookService {

    private final BookMapper bookMapper;
    private final UserMapper userMapper;

    public AdminBookService(BookMapper bookMapper, UserMapper userMapper) {
        this.bookMapper = bookMapper;
        this.userMapper = userMapper;
    }

    public Page<AdminBookListItem> list(Long ownerId,
                                         String type,
                                         String search,
                                         long page,
                                         long size) {
        long p = Math.max(1, page);
        long s = Math.min(Math.max(1, size), 100);

        QueryWrapper<Book> q = new QueryWrapper<>();
        if (ownerId != null) q.eq("owner_id", ownerId);
        if (type != null && !type.isBlank()) q.eq("type", type.trim());
        if (search != null && !search.isBlank()) q.like("name", search.trim());
        q.orderByDesc("created_at").orderByDesc("id");

        IPage<Book> mp = bookMapper.selectPage(
                new com.baomidou.mybatisplus.extension.plugins.pagination.Page<>(p, s), q);
        long total = mp.getTotal();

        // 批查 owner username
        Set<Long> ownerIds = mp.getRecords().stream()
                .map(Book::getOwnerId)
                .filter(java.util.Objects::nonNull)
                .collect(Collectors.toSet());
        Map<Long, String> usernameById = new HashMap<>();
        if (!ownerIds.isEmpty()) {
            List<User> owners = userMapper.selectBatchIds(ownerIds);
            for (User u : owners) usernameById.put(u.getId(), u.getUsername());
        }

        List<AdminBookListItem> items = mp.getRecords().stream().map(b -> new AdminBookListItem(
                b.getUuid(),
                b.getName(),
                b.getType(),
                b.getCurrency(),
                b.getOwnerId(),
                usernameById.getOrDefault(b.getOwnerId(), "unknown"),
                0,  // accountCount —— v1 不预聚合
                0,  // recordCount  —— v1 不预聚合
                b.getCreatedAt()
        )).collect(Collectors.toList());

        return new Page<>(items, total, s, p);
    }
}
