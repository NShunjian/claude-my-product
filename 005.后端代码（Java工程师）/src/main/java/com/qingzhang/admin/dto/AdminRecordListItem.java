package com.qingzhang.admin.dto;
import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
public record AdminRecordListItem(
    String uuid, String type, BigDecimal amount, String currency,
    String note, LocalDate recordDate, String source,
    long userId, String username, String bookUuid, String bookName,
    String categoryName, String accountName,
    Instant createdAt
) {}
