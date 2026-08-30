package com.qingzhang.admin.dashboard;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.qingzhang.admin.dto.AdminDashboardStats;
import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.records.entity.Record;
import com.qingzhang.records.mapper.RecordMapper;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

@Service
public class DashboardService {

    private final UserMapper userMapper;
    private final BookMapper bookMapper;
    private final AccountMapper accountMapper;
    private final RecordMapper recordMapper;

    public DashboardService(UserMapper userMapper,
                             BookMapper bookMapper,
                             AccountMapper accountMapper,
                             RecordMapper recordMapper) {
        this.userMapper = userMapper;
        this.bookMapper = bookMapper;
        this.accountMapper = accountMapper;
        this.recordMapper = recordMapper;
    }

    /**
     * readOnly 事务让所有 COUNT 共享同一 InnoDB ReadView(REPEATABLE READ 默认隔离级别),
     * 避免之前 3 个 records COUNT 各开各的 auto-commit 连接导致「总流水 / 7d 活跃 / 今日新增」
     * 看到不同快照从而 ±1 漂移的问题。用户/账本 COUNT 顺带受益,整体严格一致。
     *
     * ponytail:不锁表、不合并 SQL,一个注解搞定。race 窗口从 N × RTT 缩到 0。
     */
    @Transactional(readOnly = true)
    public AdminDashboardStats stats() {
        Instant todayStart = LocalDate.now(ZoneOffset.UTC).atStartOfDay().toInstant(ZoneOffset.UTC);
        Instant sevenDaysAgo = todayStart.minus(7, ChronoUnit.DAYS);

        long userCount = safeCount(userMapper);
        long bookCount = safeCount(bookMapper);
        long accountCount = safeCount(accountMapper);
        long recordCount = safeCount(recordMapper);

        long userNewToday = userMapper.selectCount(
                new QueryWrapper<User>().ge("created_at", todayStart));
        long recordToday = recordMapper.selectCount(
                new QueryWrapper<Record>().ge("created_at", todayStart));
        // userActive7d:用 records 数(用户有行为就算活跃)作为近似值
        long userActive7d = recordMapper.selectCount(
                new QueryWrapper<Record>().ge("created_at", sevenDaysAgo));

        return new AdminDashboardStats(
                userCount,
                userNewToday,
                userActive7d,
                bookCount,
                accountCount,
                recordCount,
                recordToday,
                last7DaysUserCounts(),
                last7DaysRecordCounts()
        );
    }

    private long safeCount(com.baomidou.mybatisplus.core.mapper.BaseMapper<?> mapper) {
        Long c = mapper.selectCount(null);
        return c == null ? 0L : c;
    }

    private List<AdminDashboardStats.DailyCount> last7DaysUserCounts() {
        List<AdminDashboardStats.DailyCount> out = new ArrayList<>(7);
        for (int i = 6; i >= 0; i--) {
            LocalDate d = LocalDate.now(ZoneOffset.UTC).minusDays(i);
            Instant start = d.atStartOfDay().toInstant(ZoneOffset.UTC);
            Instant end = start.plus(1, ChronoUnit.DAYS);
            Long c = userMapper.selectCount(
                    new QueryWrapper<User>().ge("created_at", start).lt("created_at", end));
            out.add(new AdminDashboardStats.DailyCount(d.toString(), c == null ? 0L : c));
        }
        return out;
    }

    private List<AdminDashboardStats.DailyCount> last7DaysRecordCounts() {
        List<AdminDashboardStats.DailyCount> out = new ArrayList<>(7);
        for (int i = 6; i >= 0; i--) {
            LocalDate d = LocalDate.now(ZoneOffset.UTC).minusDays(i);
            Instant start = d.atStartOfDay().toInstant(ZoneOffset.UTC);
            Instant end = start.plus(1, ChronoUnit.DAYS);
            Long c = recordMapper.selectCount(
                    new QueryWrapper<Record>().ge("created_at", start).lt("created_at", end));
            out.add(new AdminDashboardStats.DailyCount(d.toString(), c == null ? 0L : c));
        }
        return out;
    }

    // 显式 import 块外补:BaseMapper 不要在这里 import,通过类型推断;
    // 上面 safeCount 用了 raw type 是为了跨 mapper 复用。Account entity 是
    // com.qingzhang.accounts.entity.Account —— v1 不预聚合它的字段,只数总条数。
    @SuppressWarnings("unused")
    private void unused(Account a, Book b) {}
}
