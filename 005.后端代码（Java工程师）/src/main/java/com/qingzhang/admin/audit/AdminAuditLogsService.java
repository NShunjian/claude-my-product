package com.qingzhang.admin.audit;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.qingzhang.admin.dto.AdminAuditLogDetailResponse;
import com.qingzhang.admin.dto.AdminAuditLogListItem;
import com.qingzhang.admin.dto.Page;
import com.qingzhang.admin.entity.AdminAuditLog;
import com.qingzhang.admin.mapper.AdminAuditLogMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.List;
import java.util.stream.Collectors;

/**
 * 审计日志读侧 —— 与 AdminAuditService (写侧) 分离。AdminAuditLogsService 只读。
 *
 * admin_audit_logs 没有 @TableLogic,所以 selectPage 不会自动过滤 —— 全部返回。
 */
@Service
public class AdminAuditLogsService {

    private final AdminAuditLogMapper mapper;

    public AdminAuditLogsService(AdminAuditLogMapper mapper) {
        this.mapper = mapper;
    }

    public Page<AdminAuditLogListItem> list(String actorUsername,
                                             String action,
                                             String targetType,
                                             Long targetId,
                                             String result,
                                             Instant dateFrom,
                                             Instant dateTo,
                                             long page,
                                             long size) {
        long p = Math.max(1, page);
        long s = Math.min(Math.max(1, size), 100);

        QueryWrapper<AdminAuditLog> q = new QueryWrapper<>();
        if (actorUsername != null && !actorUsername.isBlank()) {
            q.eq("actor_username", actorUsername.trim());
        }
        if (action != null && !action.isBlank()) {
            q.eq("action", action.trim());
        }
        if (targetType != null && !targetType.isBlank()) {
            q.eq("target_type", targetType.trim());
        }
        if (targetId != null) q.eq("target_id", targetId);
        if (result != null && !result.isBlank()) {
            q.eq("result", result.trim());
        }
        if (dateFrom != null) q.ge("created_at", dateFrom);
        if (dateTo != null) q.le("created_at", dateTo);
        q.orderByDesc("created_at").orderByDesc("id");

        IPage<AdminAuditLog> mp = mapper.selectPage(
                new com.baomidou.mybatisplus.extension.plugins.pagination.Page<>(p, s), q);
        long total = mp.getTotal();

        List<AdminAuditLogListItem> items = mp.getRecords().stream().map(r -> new AdminAuditLogListItem(
                r.getUuid(),
                r.getActorUsername(),
                r.getAction(),
                r.getTargetType(),
                r.getTargetId(),
                r.getResult(),
                r.getCreatedAt()
        )).collect(Collectors.toList());

        return new Page<>(items, total, s, p);
    }

    public AdminAuditLogDetailResponse detail(String uuid) {
        if (uuid == null || uuid.isBlank()) {
            throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "uuid 不能为空");
        }
        AdminAuditLog log = mapper.selectOne(
                new QueryWrapper<AdminAuditLog>().eq("uuid", uuid));
        if (log == null) {
            throw new BizException(ErrorCode.ADMIN_TARGET_NOT_FOUND, "审计日志不存在: uuid=" + uuid);
        }
        return new AdminAuditLogDetailResponse(
                log.getUuid(),
                log.getActorUsername(),
                log.getActorUserId(),
                log.getAction(),
                log.getTargetType(),
                log.getTargetId(),
                log.getBeforeSnapshot(),
                log.getAfterSnapshot(),
                log.getIp(),
                log.getUserAgent(),
                log.getResult(),
                log.getErrorMsg(),
                log.getCreatedAt()
        );
    }
}
