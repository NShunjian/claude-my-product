package com.qingzhang.accounts.entity;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * v_account_balance 视图投影 —— 余额实时计算,初版前端用它渲染。
 * 与 Account 实体解耦:Account 走 accounts 表(写),AccountBalance 走视图(只读)。
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AccountBalance {

    private Long id;
    private String uuid;
    private Long userId;
    private Long bookId;
    private String name;
    private String type;
    private String icon;
    private BigDecimal initialBalance;
    private BigDecimal balance;
    private String currency;
    private Byte isDefault;
    private Byte isArchived;
    private Integer sortOrder;
    private String note;
    private Instant createdAt;
}
