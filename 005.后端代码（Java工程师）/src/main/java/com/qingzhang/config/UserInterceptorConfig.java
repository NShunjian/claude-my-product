package com.qingzhang.config;

import com.qingzhang.auth.UserAuthInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 注册 UserAuthInterceptor 到业务用户路由。
 *
 * 覆盖范围:
 *   /api/**         —— 主站全部
 *   排除 /api/admin/** —— admin 路由由 AdminInterceptorConfig 自己管,顺序先后无依赖
 *                        (两个拦截器互不重叠,UserAuthInterceptor 内对 admin 主体直接放行)
 *   排除 /api/auth/login   —— 登录端点自己发 token,无需校验
 *
 * 执行顺序 (与 AdminInterceptorConfig 独立):
 *   1. JwtAuthFilter (servlet filter) 先跑,填 attr
 *   2. UserAuthInterceptor 跑,校验 tokenVersion
 */
@Configuration
public class UserInterceptorConfig implements WebMvcConfigurer {

    private final UserAuthInterceptor userAuthInterceptor;

    public UserInterceptorConfig(UserAuthInterceptor userAuthInterceptor) {
        this.userAuthInterceptor = userAuthInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(userAuthInterceptor)
                .addPathPatterns("/api/**")
                .excludePathPatterns(
                        "/api/admin/**",      // admin 路由由 AdminAuthInterceptor 接管
                        "/api/auth/login"     // 登录端点不要求 token
                );
    }
}
