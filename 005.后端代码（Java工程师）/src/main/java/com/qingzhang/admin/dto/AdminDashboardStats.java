package com.qingzhang.admin.dto;
import java.util.List;
public record AdminDashboardStats(
    long userCount, long userNewToday, long userActive7d,
    long bookCount, long accountCount, long recordCount, long recordToday,
    List<DailyCount> newUsersLast7Days,
    List<DailyCount> newRecordsLast7Days
) {
    public record DailyCount(String date, long count) {}
}
