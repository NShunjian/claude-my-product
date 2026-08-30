package com.qingzhang.auth;

import com.baomidou.mybatisplus.core.conditions.query.QueryWrapper;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;

/**
 * 业务用户路由 (/api/** 但 /api/admin/** 已被 AdminAuthInterceptor 接管)
 * 的 tokenVersion 校验拦截器。V8 起与 admin token_version 体系对齐。
 *
 * 规则 (按顺序检查,任一失败即 short-circuit 写响应):
 *   1. JwtAuthFilter 必须已经填好 userId attr —— 没有 → 401 (1003 / 1000 由 controller 自决,这里放行)
 *   2. actorType 必须是 "user" —— admin 主体由 AdminAuthInterceptor 接管,这里放行
 *   3. tokenVersion 必须等于 users.token_version —— 不一致 → 401
 *      (账号被管理员禁/启用,或后续扩展密码重置踢出场景)
 *
 * 注意:这里**不校验 status == 1**。禁用户时调用方 UPDATE 同时 bump token_version,
 * 旧 token 走到这里就 401,不需要再多一次 SELECT users.status。
 * 如果有人绕过 updateStatus 直接改 users.status,踢不出 —— 这是已知 trade-off,
 * 接受(主站唯一禁用入口就是 BusinessUserService)。
 *
 * 不阻断请求:user 主体鉴权失败的语义由 controller 决定(401/403),这里只在
 * tokenVersion 不一致时主动 401 —— 业务用户被踢出必须立即生效。
 *
 * ponytail: 从 AdminAuthInterceptor 改,删掉了 admin-expiration-hours / RBAC / 注解解析
 * 这些无关逻辑 —— UserAuthInterceptor 只盯 tokenVersion。
 */
@Component
public class UserAuthInterceptor implements HandlerInterceptor {

    private static final Logger log = LoggerFactory.getLogger(UserAuthInterceptor.class);

    private final UserMapper userMapper;
    private final ObjectMapper objectMapper;

    public UserAuthInterceptor(UserMapper userMapper, ObjectMapper objectMapper) {
        this.userMapper = userMapper;
        this.objectMapper = objectMapper;
    }

    @Override
    public boolean preHandle(HttpServletRequest request,
                             HttpServletResponse response,
                             Object handler) throws Exception {

        // 0. handler 不是方法 (静态资源等) —— 放行
        if (!(handler instanceof HandlerMethod)) {
            return true;
        }

        // 1. 没 token → 放行,让 controller 自己返 401/1003
        Long userIdAttr = (Long) request.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (userIdAttr == null) {
            return true;
        }

        // 2. admin 主体不走这里,放行(AdminAuthInterceptor 已校验过)
        String actorType = (String) request.getAttribute(JwtAuthFilter.ACTOR_TYPE_ATTR);
        if (!JwtUtil.ACTOR_TYPE_USER.equals(actorType)) {
            return true;
        }

        // 3. tokenVersion 比对
        Long tokenVerAttr = (Long) request.getAttribute(JwtAuthFilter.TOKEN_VERSION_ATTR);
        long tokenVer = tokenVerAttr == null ? 0L : tokenVerAttr;
        Long currentVer = currentTokenVersion(userIdAttr);
        if (currentVer == null) {
            // 业务用户被删了 —— 踢出
            return reject(response, 401, ErrorCode.UNAUTHORIZED, "账号不存在,请重新登录");
        }
        if (currentVer != tokenVer) {
            // 状态/密码变更导致 tokenVersion 已 bump,旧 token 失效
            return reject(response, 401, ErrorCode.UNAUTHORIZED,
                    "账号状态已变更,请重新登录");
        }

        return true;
    }

    /** 读 users.token_version。users.id 与 JWT sub 同值域(与 admin_users.id 值域已分离)。 */
    private Long currentTokenVersion(long userId) {
        User u = userMapper.selectOne(
                new QueryWrapper<User>().select("token_version").eq("id", userId));
        if (u == null || u.getTokenVersion() == null) return null;
        return u.getTokenVersion();
    }

    private boolean reject(HttpServletResponse response, int httpStatus, int code, String message)
            throws java.io.IOException {
        response.setStatus(httpStatus);
        response.setContentType("application/json;charset=UTF-8");
        ApiResponse<Void> body = ApiResponse.fail(code, message);
        response.getWriter().write(objectMapper.writeValueAsString(body));
        log.info("[user-auth] tokenVersion mismatch: code={} msg={}", code, message);
        return false;
    }
}
