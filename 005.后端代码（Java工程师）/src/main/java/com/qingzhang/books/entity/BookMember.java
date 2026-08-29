package com.qingzhang.books.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

/**
 * 账本成员(book_members 表)。spec §5.3 V1.1。
 *
 * 注:book_members 不做软删 —— 成员被移除即 DELETE 真实行;
 * book 删除走 ON DELETE CASCADE 自动带走。
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@TableName("book_members")
public class BookMember {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long bookId;

    private Long userId;

    /** owner / admin / editor / viewer */
    private String role;

    private Instant joinedAt;

    private Long invitedBy;
}
