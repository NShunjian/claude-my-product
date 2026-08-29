package com.qingzhang.accounts.entity;

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

import java.math.BigDecimal;
import java.time.Instant;

/**
 * accounts 表实体(spec §6.1)。
 *
 * 业务字段:`current_balance` 是冗余缓存,真实余额走 v_account_balance 视图;
 * 写操作不维护 current_balance(由视图实时算),仅在 records 联动后留作预留。
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@TableName("accounts")
public class Account {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String uuid;

    private Long userId;

    private Long bookId;

    private String name;

    private String icon;

    /** cash / debit / credit / wallet / investment / other */
    private String type;

    private BigDecimal initialBalance;

    private BigDecimal currentBalance;

    private String currency;

    private Byte isDefault;

    private Byte isArchived;

    private Integer sortOrder;

    private String note;

    private Instant createdAt;

    private Instant updatedAt;

    @TableLogic
    @TableField(select = false)
    private Instant deletedAt;
}
