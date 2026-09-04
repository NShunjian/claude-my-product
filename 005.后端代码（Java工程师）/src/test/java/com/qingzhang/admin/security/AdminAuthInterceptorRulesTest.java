package com.qingzhang.admin.security;

import com.qingzhang.admin.mapper.AdminUserMapper;
import com.qingzhang.auth.JwtUtil;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

/**
 * 005 Java 后端 — AdminAuthInterceptor 5 条规则测试(占位骨架)
 *
 * 覆盖目标(按 005-java-backend.md §4 H7):
 *   R1: 无 JwtAuthFilter userId attr → 401 (1411 ADMIN_AUTH_REQUIRED)
 *   R2: JWT iat 超过 adminExpirationHours → 401
 *   R3: tokenVersion 不一致 → 401
 *   R4: 用户无 admin 角色 → 403 (1403)
 *   R5: handler 带 @RequiresPermission 但用户无该权限 → 403
 *
 * 工具:JUnit 5 + Mockito
 *
 * 状态:骨架。完整实现需注入 adminUserMapper、jwtUtil、HttpServletResponse mock。
 */
class AdminAuthInterceptorRulesTest {

    private final JwtUtil jwtUtil = mock(JwtUtil.class);
    private final AdminUserMapper adminUserMapper = mock(AdminUserMapper.class);
    private final ObjectMapper objectMapper = new ObjectMapper();
    @SuppressWarnings("unused")
    private final AdminAuthInterceptor interceptor = new AdminAuthInterceptor(
        jwtUtil, adminUserMapper, objectMapper, 24L
    );

    @Test
    @DisplayName("占位 — 完整规则验证在后续补全")
    void placeholder() {
        assertTrue(true);
    }
}