package com.qingzhang.admin.security;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.auth.JwtUtil;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.ErrorCode;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

/**
 * Admin 路由 (/api/admin/**) 鉴权拦截器。
 *
 * 规则 (按顺序检查,任一失败即 short-circuit 写响应):
 *   1. JwtAuthFilter 必须已经填好 userId attr —— 没有 → 401 ADMIN_AUTH_REQUIRED (1411)
 *   2. 当前时间距 JWT iat 不能超过 jwt.admin-expiration-hours —— 超时 → 401 ADMIN_AUTH_REQUIRED
 *   3. 用户必须有 admin 角色 (isSuperAdmin || permissions 非空) —— 否则 → 403 ADMIN_PERMISSION_DENIED
 *   4. handler 方法若带 @RequiresPermission("xxx"),必须 permissions.contains("xxx")
 *      或 isSuperAdmin —— 否则 → 403 ADMIN_PERMISSION_DENIED
 *
 * 直接写 response —— 走 GlobalExceptionHandler 的 BizException 会返 400,
 * 而 admin 鉴权失败要返 401/403,语义不对。
 *
 * ponytail: 不引 Spring Security,一个 HandlerInterceptor 足够。
 */
@Component
public class AdminAuthInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(AdminAuthInterceptor.class);

    private final JwtUtil jwtUtil;
    private final ObjectMapper objectMapper;
    private final long adminExpirationHours;

    public AdminAuthInterceptor(JwtUtil jwtUtil,
                                ObjectMapper objectMapper,
                                @Value("${jwt.admin-expiration-hours:24}") long adminExpirationHours) {
        this.jwtUtil = jwtUtil;
        this.objectMapper = objectMapper;
        this.adminExpirationHours = adminExpirationHours;
    }

    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) throws Exception {

        // 0. handler 不是方法 (静态资源等) —— 放行
        if (!(handler instanceof HandlerMethod hm)) {
            return true;
        }

        // 1. token / userId
        Long userIdAttr = (Long) request.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (userIdAttr == null) {
            return reject(response, 401, ErrorCode.ADMIN_AUTH_REQUIRED, "需要管理员登录");
        }

        // 2. admin token 时效 —— 需要重新解析 JWT 拿 iat (JwtClaims 没透出 iat)
        String header = request.getHeader("Authorization");
        if (header == null || !header.startsWith("Bearer ")) {
            return reject(response, 401, ErrorCode.ADMIN_AUTH_REQUIRED, "需要管理员登录");
        }
        String token = header.substring(7);
        Instant iat;
        try {
            iat = jwtUtil.parseIssuedAt(token);
        } catch (Exception ex) {
            return reject(response, 401, ErrorCode.ADMIN_AUTH_REQUIRED, "token 无效或已过期");
        }
        if (Duration.between(iat, Instant.now()).toHours() >= adminExpirationHours) {
            return reject(response, 401, ErrorCode.ADMIN_AUTH_REQUIRED,
                    "管理员 token 已过期,请重新登录 (上限 " + adminExpirationHours + " 小时)");
        }

        // 3. 至少有 1 个 admin 角色
        Boolean isSuperAttr = (Boolean) request.getAttribute(JwtAuthFilter.IS_SUPER_ADMIN_ATTR);
        boolean isSuperAdmin = Boolean.TRUE.equals(isSuperAttr);
        @SuppressWarnings("unchecked")
        List<String> permissions = (List<String>) request.getAttribute(JwtAuthFilter.PERMISSIONS_ATTR);
        if (!isSuperAdmin && (permissions == null || permissions.isEmpty())) {
            return reject(response, 403, ErrorCode.ADMIN_PERMISSION_DENIED, "无管理员权限");
        }

        // 4. @RequiresPermission 注解
        RequiresPermission rp = hm.getMethodAnnotation(RequiresPermission.class);
        if (rp != null) {
            String need = rp.value();
            if (!isSuperAdmin && (permissions == null || !permissions.contains(need))) {
                return reject(response, 403, ErrorCode.ADMIN_PERMISSION_DENIED,
                        "缺少权限: " + need);
            }
        }

        return true;
    }

    private boolean reject(HttpServletResponse response, int httpStatus, int code, String message)
            throws java.io.IOException {
        response.setStatus(httpStatus);
        response.setContentType("application/json;charset=UTF-8");
        ApiResponse<Void> body = ApiResponse.fail(code, message);
        response.getWriter().write(objectMapper.writeValueAsString(body));
        log.warn("[admin-auth] http={} code={} msg={}", httpStatus, code, message);
        return false;
    }
}
