package com.qingzhang.categories.entity;

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
@TableName("categories")
public class Category {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String uuid;

    private Long userId;

    private Long bookId;

    /** expense / income */
    private String type;

    private String name;

    private String icon;

    private String color;

    private Byte isPreset;

    private Byte isActive;

    private Integer sortOrder;

    private Instant createdAt;

    private Instant updatedAt;

    @TableLogic
    @TableField(select = false)
    private Instant deletedAt;
}
