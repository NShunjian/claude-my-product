package com.qingzhang.admin.audit;

import com.baomidou.dynamic.datasource.annotation.DS;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qingzhang.admin.entity.AdminAuditLog;
import com.qingzhang.admin.mapper.AdminAuditLogMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;

/**
 * 写 admin_audit_logs。
 *
 * v1:每个 admin service 在变更成功后手动调用,不引 AOP(拦截面 + 性能 + 调试都不值得)。
 * 后续若需要全量审计,改成 @AuditAction 注解 + AOP 即可,接口不变。
 *
 * ponytail:用 ObjectMapper 把 before/after 对象序列化成 JSON 字符串入库。
 */
@Service
@DS("admin")
public class AdminAuditService {

    private static final Logger log = LoggerFactory.getLogger(AdminAuditService.class);

    private final AdminAuditLogMapper auditLogMapper;
    private final ObjectMapper objectMapper;

    public AdminAuditService(AdminAuditLogMapper auditLogMapper, ObjectMapper objectMapper) {
        this.auditLogMapper = auditLogMapper;
        this.objectMapper = objectMapper;
    }

    /** 记录一次成功的 admin 操作。before / after 可为 null —— 仅审计"操作存在",无需 diff。 */
    public void recordSuccess(long actorAdminUserId,
                              String actorUsername,
                              String action,
                              String targetType,
                              Long targetId,
                              Object before,
                              Object after,
                              String ip,
                              String userAgent) {
        AdminAuditLog entry = AdminAuditLog.builder()
                .uuid(UUID.randomUUID().toString())
                .actorAdminUserId(actorAdminUserId)
                .actorUsername(actorUsername)
                .action(action)
                .targetType(targetType)
                .targetId(targetId)
                .beforeSnapshot(toJson(before))
                .afterSnapshot(toJson(after))
                .ip(ip)
                .userAgent(userAgent)
                .result("success")
                .createdAt(Instant.now())
                .build();
        try {
            auditLogMapper.insert(entry);
        } catch (Exception ex) {
            // 审计失败不阻断主流程,但记 ERROR 以便排查
            log.error("[audit] 写审计日志失败: action={} actor={} target={}#{}",
                    action, actorUsername, targetType, targetId, ex);
        }
    }

    /** 记录一次失败的 admin 操作 (例如尝试改一个不存在的用户)。 */
    public void recordFailure(long actorAdminUserId,
                              String actorUsername,
                              String action,
                              String targetType,
                              Long targetId,
                              String errorMsg,
                              String ip,
                              String userAgent) {
        AdminAuditLog entry = AdminAuditLog.builder()
                .uuid(UUID.randomUUID().toString())
                .actorAdminUserId(actorAdminUserId)
                .actorUsername(actorUsername)
                .action(action)
                .targetType(targetType)
                .targetId(targetId)
                .ip(ip)
                .userAgent(userAgent)
                .result("failure")
                .errorMsg(errorMsg)
                .createdAt(Instant.now())
                .build();
        try {
            auditLogMapper.insert(entry);
        } catch (Exception ex) {
            log.error("[audit] 写审计日志失败: action={} actor={} err={}", action, actorUsername, errorMsg, ex);
        }
    }

    private String toJson(Object o) {
        if (o == null) return null;
        try {
            return objectMapper.writeValueAsString(o);
        } catch (JsonProcessingException ex) {
            log.warn("[audit] JSON 序列化失败: {}", ex.getMessage());
            return null;
        }
    }
}
