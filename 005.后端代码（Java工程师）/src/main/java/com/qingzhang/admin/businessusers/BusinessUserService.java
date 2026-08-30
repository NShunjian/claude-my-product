package com.qingzhang.admin.businessusers;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.qingzhang.admin.audit.AdminAuditService;
import com.qingzhang.admin.businessusers.dto.BusinessUserDetailResponse;
import com.qingzhang.admin.businessusers.dto.BusinessUserListItem;
import com.qingzhang.admin.dto.AdminResetPasswordResponse;
import com.qingzhang.admin.security.AdminActor;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
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
    private final AdminAuditService auditService;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final SecureRandom random = new SecureRandom();

    public BusinessUserService(UserMapper userMapper, AdminAuditService auditService) {
        this.userMapper = userMapper;
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

        Byte before = u.getStatus();
        u.setStatus((byte) (enabled ? 1 : 0));
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);

        String action = enabled ? "business_user.enable" : "business_user.disable";
        auditService.recordSuccess(actor.userId(), actor.username(),
                action, "business_user", userId,
                Map.of("status", before), Map.of("status", u.getStatus()),
                actor.ip(), actor.userAgent());

        return u.getStatus();
    }

    /** 重置业务用户密码 —— 12 位随机,BCrypt 入库,返回明文。审计: business_user.reset_password。 */
    @Transactional(rollbackFor = Exception.class)
    public AdminResetPasswordResponse resetPassword(long userId, AdminActor actor) {
        User u = mustUser(userId);
        String newPassword = generatePassword(12);
        u.setPasswordHash(encoder.encode(newPassword));
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);

        auditService.recordSuccess(actor.userId(), actor.username(),
                "business_user.reset_password", "business_user", userId,
                null, Map.of("password_changed", true), actor.ip(), actor.userAgent());
        log.info("[admin] business user password reset: actor={} target={}", actor.username(), userId);
        return new AdminResetPasswordResponse(newPassword);
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