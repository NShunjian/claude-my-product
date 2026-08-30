package com.qingzhang.admin.security;

import com.baomidou.dynamic.datasource.annotation.DS;
import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qingzhang.admin.entity.AdminUser;
import com.qingzhang.admin.mapper.AdminUserMapper;
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
 *   3. tokenVersion 必须等于 admin_users.token_version —— 不一致 → 401(账号状态/角色已变更)
 *   4. 用户必须有 admin 角色 (isSuperAdmin || permissions 非空) —— 否则 → 403 ADMIN_PERMISSION_DENIED
 *   5. handler 方法若带 @RequiresPermission("xxx"),必须 permissions.contains("xxx")
 *      或 isSuperAdmin —— 否则 → 403 ADMIN_PERMISSION_DENIED
 *
 * 直接写 response —— 走 GlobalExceptionHandler 的 BizException 会返 400,
 * 而 admin 鉴权失败要返 401/403,语义不对。
 *
 * ponytail: 不引 Spring Security,一个 HandlerInterceptor 足够。
 */
@Component
@DS("admin")
public class AdminAuthInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(AdminAuthInterceptor.class);

    private final JwtUtil jwtUtil;
    private final AdminUserMapper adminUserMapper;
    private final ObjectMapper objectMapper;
    private final long adminExpirationHours;

    public AdminAuthInterceptor(JwtUtil jwtUtil,
                                AdminUserMapper adminUserMapper,
                                ObjectMapper objectMapper,
                                @Value("${jwt.admin-expiration-hours:24}") long adminExpirationHours) {
        this.jwtUtil = jwtUtil;
        this.adminUserMapper = adminUserMapper;
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

        // 3. tokenVersion 作废校验 —— 仅对 admin 主体生效
        //    普通 user 主体不查 admin_users,放行(避免误伤主业务侧 token)
        String actorType = (String) request.getAttribute(JwtAuthFilter.ACTOR_TYPE_ATTR);
        if (JwtUtil.ACTOR_TYPE_ADMIN.equals(actorType)) {
            Long tokenVerAttr = (Long) request.getAttribute(JwtAuthFilter.TOKEN_VERSION_ATTR);
            long tokenVer = tokenVerAttr == null ? 0L : tokenVerAttr;
            Long currentVer = currentTokenVersion(userIdAttr);
            if (currentVer == null) {
                return reject(response, 401, ErrorCode.ADMIN_AUTH_REQUIRED, "账号不存在");
            }
            // 任何一边非 0 都按比对处理;初始 DB=0 / 老 token(无 claim)默认 0,二者相等时仍放行
            // 一旦有状态/角色变更 DB 自增,旧 token (claim=0) 即被踢出
            if (currentVer != tokenVer) {
                return reject(response, 401, ErrorCode.ADMIN_AUTH_REQUIRED,
                        "账号状态或权限已变更,请重新登录");
            }
        }

        // 4. 至少有 1 个 admin 角色
        Boolean isSuperAttr = (Boolean) request.getAttribute(JwtAuthFilter.IS_SUPER_ADMIN_ATTR);
        boolean isSuperAdmin = Boolean.TRUE.equals(isSuperAttr);
        @SuppressWarnings("unchecked")
        List<String> permissions = (List<String>) request.getAttribute(JwtAuthFilter.PERMISSIONS_ATTR);
        if (!isSuperAdmin && (permissions == null || permissions.isEmpty())) {
            return reject(response, 403, ErrorCode.ADMIN_PERMISSION_DENIED, "无管理员权限");
        }

        // 5. @RequiresPermission 注解
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

    /** 读 admin_users.token_version。admin_users.id 与 JWT sub 同值域。 */
    private Long currentTokenVersion(long userId) {
        AdminUser u = adminUserMapper.selectOne(
                new QueryWrapper<AdminUser>().select("token_version").eq("id", userId));
        if (u == null || u.getTokenVersion() == null) return null;
        return u.getTokenVersion();
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
