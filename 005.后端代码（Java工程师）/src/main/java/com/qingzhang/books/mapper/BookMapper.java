package com.qingzhang.books.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.qingzhang.books.entity.Book;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface BookMapper extends BaseMapper<Book> {

    /**
     * 列出当前用户「拥有 + 加入」的所有账本。一条 SQL 解决(owner_id = 自己 OR 在 book_members 中)。
     * 同时返回当前用户在该账本的角色(role),左连 join 一次性出。
     */
    @Select("""
            SELECT
              b.id, b.uuid, b.owner_id, b.name, b.description, b.type, b.currency,
              b.is_default, b.is_archived, b.sort_order, b.created_at, b.updated_at,
              CASE
                WHEN b.owner_id = #{userId} THEN 'owner'
                ELSE m.role
              END AS user_role
            FROM books b
            LEFT JOIN book_members m
              ON m.book_id = b.id AND m.user_id = #{userId}
            WHERE b.deleted_at IS NULL
              AND (b.owner_id = #{userId} OR m.user_id = #{userId})
            ORDER BY b.is_default DESC, b.sort_order ASC, b.id ASC
            """)
    List<BookWithRole> listForUser(@Param("userId") long userId);

    /** listForUser 的返回行(b.* + user_role 列)。 */
    record BookWithRole(
            Long id,
            String uuid,
            Long ownerId,
            String name,
            String description,
            String type,
            String currency,
            Byte isDefault,
            Byte isArchived,
            Integer sortOrder,
            java.time.Instant createdAt,
            java.time.Instant updatedAt,
            String userRole
    ) {}
}
