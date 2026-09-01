package com.qingzhang.records.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@TableName("records")
public class Record {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String uuid;

    private Long userId;

    private Long bookId;

    /** expense / income / transfer */
    private String type;

    private Long categoryId;

    private Long accountId;

    private Long toAccountId;

    private BigDecimal amount;

    private String currency;

    private String note;

    private LocalDate recordDate;

    /** manual / import / ocr / auto / sync */
    private String source;

    private String location;

    private String clientId;

    private Instant createdAt;

    private Instant updatedAt;
}