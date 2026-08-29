package com.qingzhang.config;

import com.qingzhang.auth.JwtAuthFilter;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 显式注册 JwtAuthFilter,使 JwtAuthFilter 在 Spring Security 缺席下也能跑。
 * 范围:除 /api/auth/login 与 /api/auth/register 之外的所有路径都过 filter
 * (即便没 token 也放行——由 controller 自己决定要不要 userId)。
 */
@Configuration
public class AuthFilterConfig {

    @Bean
    public FilterRegistrationBean<JwtAuthFilter> jwtFilterRegistration(JwtAuthFilter filter) {
        FilterRegistrationBean<JwtAuthFilter> reg = new FilterRegistrationBean<>(filter);
        reg.addUrlPatterns("/api/*");
        reg.setOrder(1);
        return reg;
    }
}
