package com.qingzhang.admin.businessusers;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.admin.audit.AdminAuditService;
import com.qingzhang.admin.businessusers.dto.BatchDeleteBusinessUsersResponse;
import com.qingzhang.admin.businessusers.dto.BusinessUserDetailResponse;
import com.qingzhang.admin.businessusers.dto.BusinessUserListItem;
import com.qingzhang.admin.dto.AdminResetPasswordResponse;
import com.qingzhang.admin.security.AdminActor;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.categories.mapper.CategoryMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.records.mapper.RecordMapper;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 业务用户治理 —— super_admin / admin 用来管理 java-qingzhang.users。
 *
 * 跨库设计:
 *   - 业务行读写:走 master DB (UserMapper,@DS 默认未加)
 *   - 审计行写入:走 admin DB (AdminAuditService 内部 @DS("admin"))
 * 故意不放进同一个 @Transactional —— 不同 DB 实例,跨库事务需要 JTA / Seata
 * 才能严格一致;此处接受"业务成功 + 审计偶发失败"的可能性(AdminAuditService
 * 已 try/catch 兜底,失败只 log,不抛)。
 *
 * 权限边界:
 *   - super_admin + admin 都能调用(走 @RequiresPermission("business_user:*"))
 *   - viewer 没 business_user:* 权限,自动 1403
 *
 * ponytail:密码生成沿用 AdminUserService.ALPHABET —— 复制 12 行,暂不抽 util
 * 因为 admin / business 两个用户域密码策略可能演进,先各写各的。
 */
@Service
public class BusinessUserService {

    private static final Logger log = LoggerFactory.getLogger(BusinessUserService.class);
    private static final String ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";

    private final UserMapper userMapper;
    private final BookMapper bookMapper;
    private final RecordMapper recordMapper;
    private final AccountMapper accountMapper;
    private final CategoryMapper categoryMapper;
    private final AdminAuditService auditService;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final SecureRandom random = new SecureRandom();

    public BusinessUserService(UserMapper userMapper,
                                BookMapper bookMapper,
                                RecordMapper recordMapper,
                                AccountMapper accountMapper,
                                CategoryMapper categoryMapper,
                                AdminAuditService auditService) {
        this.userMapper = userMapper;
        this.bookMapper = bookMapper;
        this.recordMapper = recordMapper;
        this.accountMapper = accountMapper;
        this.categoryMapper = categoryMapper;
        this.auditService = auditService;
    }

    /** 列业务用户 —— 支持 search (username LIKE)、status 过滤,分页。 */
    public com.qingzhang.admin.dto.Page<BusinessUserListItem> list(String search,
                                           Byte status,
                                           long page,
                                           long size) {
        long p = Math.max(1, page);
        long s = Math.min(Math.max(1, size), 100);

        QueryWrapper<User> q = new QueryWrapper<>();
        if (search != null && !search.isBlank()) {
            q.like("username", search.trim());
        }
        if (status != null) {
            q.eq("status", status);
        }
        q.orderByDesc("id");

        IPage<User> mp = userMapper.selectPage(new Page<>(p, s), q);
        long total = mp.getTotal();

        List<BusinessUserListItem> items = mp.getRecords().stream().map(u -> new BusinessUserListItem(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                u.getAvatar(),
                u.getStatus(),
                u.getLastLoginAt(),
                u.getCreatedAt(),
                0,  // bookCount —— v1 不预聚合
                0   // recordCount —— v1 不预聚合
        )).collect(Collectors.toList());

        return new com.qingzhang.admin.dto.Page<>(items, total, s, p);
    }

    /** 详情 —— 全字段(不含密码哈希)。 */
    public BusinessUserDetailResponse detail(long userId) {
        User u = mustUser(userId);
        return new BusinessUserDetailResponse(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                u.getAvatar(),
                u.getGender(),
                u.getAge(),
                u.getEmail(),
                u.getPhone(),
                u.getStatus(),
                u.getLastLoginAt(),
                u.getLastLoginIp(),
                u.getCreatedAt(),
                u.getUpdatedAt()
        );
    }

    /** 启用/禁用业务用户。审计: business_user.enable / business_user.disable。 */
    @Transactional(rollbackFor = Exception.class)
    public Byte updateStatus(long userId, boolean enabled, AdminActor actor) {
        User u = mustUser(userId);

        Byte beforeStatus = u.getStatus();
        long beforeTv = u.getTokenVersion() == null ? 0L : u.getTokenVersion();

        u.setStatus((byte) (enabled ? 1 : 0));
        // V8 起:禁/启用都 bump token_version,让该用户所有现存 JWT 立即失效
        // —— 业务用户刷新页面 / 调任意接口都会被 UserAuthInterceptor 踢出。
        // 启用后用户重新登录拿新 token(DB 已 bump,新 token 写入新 claim 后通过)。
        u.setTokenVersion(beforeTv + 1L);
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);

        String action = enabled ? "business_user.enable" : "business_user.disable";
        auditService.recordSuccess(actor.userId(), actor.username(),
                action, "business_user", userId,
                Map.of("status", beforeStatus, "token_version", beforeTv),
                Map.of("status", u.getStatus(), "token_version", u.getTokenVersion()),
                actor.ip(), actor.userAgent());

        return u.getStatus();
    }

    /** 重置业务用户密码 —— 12 位随机,BCrypt 入库,返回明文。审计: business_user.reset_password。 */
    @Transactional(rollbackFor = Exception.class)
    public AdminResetPasswordResponse resetPassword(long userId, AdminActor actor) {
        User u = mustUser(userId);
        String newPassword = generatePassword(12);
        long beforeTv = u.getTokenVersion() == null ? 0L : u.getTokenVersion();
        u.setPasswordHash(encoder.encode(newPassword));
        // V8 起:重置密码也 bump token_version —— 旧密码 BCrypt 不再匹配(virtually 立即失效),
        // 同时旧 JWT 立即失效,被重置者所有 session 必须重新登录(用新密码)。
        u.setTokenVersion(beforeTv + 1L);
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);

        auditService.recordSuccess(actor.userId(), actor.username(),
                "business_user.reset_password", "business_user", userId,
                Map.of("token_version", beforeTv),
                Map.of("password_changed", true, "token_version", u.getTokenVersion()),
                actor.ip(), actor.userAgent());
        log.info("[admin] business user password reset: actor={} target={} token_version {} → {}",
                actor.username(), userId, beforeTv, u.getTokenVersion());
        return new AdminResetPasswordResponse(newPassword);
    }

    /**
     * 硬删单个业务用户 —— 不可恢复,绕过 @TableLogic,真 DELETE FROM。
     *
     * 销毁链(7 张表 + 旁路表):
     *   1. records  ─ 先删,否则 records.book_id RESTRICT 拒删 books
     *   2. books    ─ CASCADE 清 book_members / budgets;SET NULL 清 accounts.book_id / categories.book_id
     *   3. accounts ─ 显式删(为准确计数;FK CASCADE 也会从 user 删除触发)
     *   4. categories ─ 显式删(同上)
     *   5. users    ─ CASCADE 清 export_logs / 残留 book_members / 残留 budgets
     *
     * 已软删 / 不存在的 user 抛 not found(单删场景不能 silently skip)。
     *
     * audit: business_user.hard_delete。
     */
    @Transactional(rollbackFor = Exception.class)
    public BatchDeleteBusinessUsersResponse delete(long userId, AdminActor actor) {
        if (userMapper.existsLive(userId) == 0) {
            throw new BizException(ErrorCode.USER_NOT_FOUND, "业务用户不存在或已被删除: id=" + userId);
        }
        BatchDeleteBusinessUsersResponse r = hardDeleteOne(userId);
        auditService.recordSuccess(actor.userId(), actor.username(),
                "business_user.hard_delete", "business_user", userId,
                null,
                Map.of("usersDeleted", r.usersDeleted(),
                        "booksDeleted", r.booksDeleted(),
                        "recordsDeleted", r.recordsDeleted(),
                        "accountsDeleted", r.accountsDeleted(),
                        "categoriesDeleted", r.categoriesDeleted()),
                actor.ip(), actor.userAgent());
        log.info("[admin] business user hard delete: actor={} target={} {}", actor.username(), userId, r);
        return r;
    }

    /**
     * 批量硬删业务用户 —— 不可恢复。
     *
     * 校验:
     *   - ids 非空、≤ 100
     *   - 不存在 / 已软删的 id 计入 skipped,不 throw(批量场景允许「5 个里有 1 个已删」整体仍成功)
     *
     * 累计每个表的销毁行数返回,前端 toast 文案按 totals 显示。
     */
    @Transactional(rollbackFor = Exception.class)
    public BatchDeleteBusinessUsersResponse batchDelete(List<Long> ids, AdminActor actor) {
        if (ids == null || ids.isEmpty()) {
            throw new BizException(ErrorCode.VALIDATION_FAILED, "请选择至少一个用户");
        }
        if (ids.size() > 100) {
            throw new BizException(ErrorCode.VALIDATION_FAILED,
                    "单次最多删除 100 个用户,当前选了 " + ids.size() + " 个");
        }

        // 去重 + 过滤负数 / 0
        List<Long> cleanIds = ids.stream()
                .filter(id -> id != null && id > 0)
                .distinct()
                .toList();
        if (cleanIds.isEmpty()) {
            return new BatchDeleteBusinessUsersResponse(0, 0, 0, 0, 0, ids.size());
        }

        int totalUsers = 0, totalBooks = 0, totalRecords = 0, totalAccounts = 0, totalCategories = 0;
        int skipped = 0;

        for (Long id : cleanIds) {
            if (userMapper.existsLive(id) == 0) {
                skipped++;
                continue;
            }
            BatchDeleteBusinessUsersResponse r = hardDeleteOne(id);
            totalUsers += r.usersDeleted();
            totalBooks += r.booksDeleted();
            totalRecords += r.recordsDeleted();
            totalAccounts += r.accountsDeleted();
            totalCategories += r.categoriesDeleted();
        }

        BatchDeleteBusinessUsersResponse r = new BatchDeleteBusinessUsersResponse(
                totalUsers, totalBooks, totalRecords, totalAccounts, totalCategories, skipped);
        auditService.recordSuccess(actor.userId(), actor.username(),
                "business_user.batch_hard_delete", "business_user", null,
                Map.of("ids", ids),
                Map.of("usersDeleted", totalUsers,
                        "booksDeleted", totalBooks,
                        "recordsDeleted", totalRecords,
                        "accountsDeleted", totalAccounts,
                        "categoriesDeleted", totalCategories,
                        "skipped", skipped),
                actor.ip(), actor.userAgent());
        log.info("[admin] business user batch hard delete: actor={} requested={} {}", actor.username(), ids.size(), r);
        return r;
    }

    /**
     * 真硬删一个用户及其所有数据。返回 5 个计数。不可恢复,操作员需在 confirm dialog 二次确认。
     *
     * 销毁顺序见 delete() 方法注释 —— records 必须先于 books。
     */
    private BatchDeleteBusinessUsersResponse hardDeleteOne(long userId) {
        // 1. records 先(records.book_id RESTRICT books)
        int records = recordMapper.hardDeleteByUserId(userId);
        // 2. books(CASCADE: book_members, budgets;SET NULL: accounts.book_id, categories.book_id)
        int books = bookMapper.hardDeleteByOwnerId(userId);
        // 3. accounts(显式,准确计数)
        int accounts = accountMapper.hardDeleteByUserId(userId);
        // 4. categories(显式,准确计数)
        int categories = categoryMapper.hardDeleteByUserId(userId);
        // 5. users(CASCADE: export_logs, 残留 book_members/budgets)
        int users = userMapper.hardDeleteByIdLive(userId);
        return new BatchDeleteBusinessUsersResponse(users, books, records, accounts, categories, 0);
    }

    /** 预览硬删某用户的销毁规模 —— 前端 confirm dialog 文案用。可选调用。 */
    public HardDeletePreview preview(long userId) {
        if (userMapper.existsLive(userId) == 0) {
            throw new BizException(ErrorCode.USER_NOT_FOUND, "业务用户不存在或已被删除: id=" + userId);
        }
        return new HardDeletePreview(
                userId,
                bookMapper.countByOwnerId(userId),
                recordMapper.countByUserId(userId),
                accountMapper.countByUserId(userId),
                categoryMapper.countByUserId(userId));
    }

    /** 硬删预览响应 —— 让前端在 confirm 前显示具体销毁规模。 */
    public record HardDeletePreview(
            long userId,
            int books,
            int records,
            int accounts,
            int categories
    ) {
    }

    // -------- helpers --------

    private User mustUser(long userId) {
        User u = userMapper.selectById(userId);
        if (u == null) {
            throw new BizException(ErrorCode.USER_NOT_FOUND, "业务用户不存在: id=" + userId);
        }
        return u;
    }

    private String generatePassword(int len) {
        StringBuilder sb = new StringBuilder(len);
        for (int i = 0; i < len; i++) {
            sb.append(ALPHABET.charAt(random.nextInt(ALPHABET.length())));
        }
        return sb.toString();
    }
}