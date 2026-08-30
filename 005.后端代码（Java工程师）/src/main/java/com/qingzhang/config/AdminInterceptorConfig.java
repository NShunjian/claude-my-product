package com.qingzhang.config;

import com.qingzhang.admin.security.AdminAuthInterceptor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 注册 AdminAuthInterceptor 到 /api/admin/**。
 *
 * 注意:JwtAuthFilter (servlet filter) 先跑,把 userId/permissions/roleCodes/
 * isSuperAdmin 填到 request attr;AdminAuthInterceptor (Spring MVC interceptor)
 * 后跑,从 attr 读 —— 这就是 A3 → A4 的执行顺序契约,见 ledger。
 */
@Configuration
public class AdminInterceptorConfig implements WebMvcConfigurer {

    private final AdminAuthInterceptor adminAuthInterceptor;

    public AdminInterceptorConfig(AdminAuthInterceptor adminAuthInterceptor) {
        this.adminAuthInterceptor = adminAuthInterceptor;
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(adminAuthInterceptor)
                .addPathPatterns("/api/admin/**")
                // 登录端点不要求 token —— 自己发 token
                .excludePathPatterns("/api/admin/auth/login");
    }
}
