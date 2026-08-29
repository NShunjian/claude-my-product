package com.qingzhang.auth;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * 把 Authorization: Bearer <token> 里的 userId 解析出来放到请求属性 "userId"。
 * 不阻断请求(没 token 也放过)—— 鉴权由 controller 决定哪些接口要 userId;
 * 缺失或非法 token 时仅记 WARN,留 controller 用 BizException 返 401。
 *
 * ponytail: 不引全套 Spring Security,一个 OncePerRequestFilter 足够。
 */
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(JwtAuthFilter.class);
    public static final String USER_ID_ATTR = "userId";

    private final JwtUtil jwtUtil;

    public JwtAuthFilter(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req,
                                    HttpServletResponse res,
                                    FilterChain chain) throws ServletException, IOException {
        String header = req.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7);
            try {
                long userId = jwtUtil.parseSubject(token);
                req.setAttribute(USER_ID_ATTR, userId);
            } catch (Exception ex) {
                log.warn("[jwt] token 解析失败: {}", ex.getMessage());
            }
        }
        chain.doFilter(req, res);
    }
}
