package com.qingzhang.config;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 开发期 CORS:放行 Vite 默认端口 5173/5174/5180/5181 + Flutter web 8080。
 * 前端走同源时无影响;若用 vite proxy 把 /api 转给后端,本配置冗余但不冲突。
 *
 * LAN 段的 origin 从 application.yml 的 {@code lan.ip} 读(由 root .env 的 {@code LAN_IP} 提供),
 * 换 WiFi 改 root .env 一处即可,无须再改这里。
 *
 * ponytail: 仅开发配置。生产用同源或反代,删这里。
 */
@Configuration
public class CorsConfig implements WebMvcConfigurer {

    /** 局域网 IP(从 root .env 的 LAN_IP 注入),用于拼 http://${lan.ip}:port。 */
    @Value("${lan.ip:localhost}")
    private String lanIp;

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(
                        "http://localhost:5173",
                        "http://127.0.0.1:5173",
                        "http://localhost:5174",
                        "http://127.0.0.1:5174",
                        "http://localhost:5180",
                        "http://127.0.0.1:5180",
                        "http://localhost:5181",
                        "http://127.0.0.1:5181",
                        // VS Code Flutter 调试默认端口(flutter run -d chrome 不带 --web-port 时)
                        "http://localhost:8080",
                        "http://127.0.0.1:8080",
                        // 局域网访问 — 由 lan.ip 拼出,换 WiFi 改 root .env 的 LAN_IP
                        "http://" + lanIp + ":5173",
                        "http://" + lanIp + ":5174",
                        "http://" + lanIp + ":5180",
                        "http://" + lanIp + ":5181"
                )
                .allowedMethods("GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .allowCredentials(false)
                .maxAge(3600);
    }
}
