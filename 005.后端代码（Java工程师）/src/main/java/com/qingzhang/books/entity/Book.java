package com.qingzhang.books.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@TableName("books")
public class Book {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String uuid;

    private Long ownerId;

    private String name;

    private String description;

    /** personal / shared / business */
    private String type;

    private String currency;

    private Byte isDefault;

    private Byte isArchived;

    private Integer sortOrder;

    private Instant createdAt;

    private Instant updatedAt;

    @TableLogic
    @TableField(select = false)
    private Instant deletedAt;
}
