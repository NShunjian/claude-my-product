package com.qingzhang.auth;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.Date;
import java.util.List;

/**
 * HS256 JWT。密钥从 application.yml 的 jwt.secret 读,默认 7 天过期。
 *
 * Claims:
 *   sub               = userId (String)
 *   permissions       = List<String> 权限码集合
 *   roleCodes         = List<String> 角色码集合 (admin_roles.code)
 *   isSuperAdmin      = boolean
 *
 * 非管理员用户 permissions/roleCodes 为空列表,isSuperAdmin=false。
 * 老 token (无 admin claims) 解析时降级为空集合 — 不抛异常。
 *
 * ponytail: 与 Node 端 jsonwebtoken 互通要求同算法(HS256)+ 同密钥;密钥在
 * application.yml 占位,真正部署时改成与 Node .env 一致的值,见 README。
 */
@Component
public class JwtUtil {

    @Value("${jwt.secret:please-change-me-in-application-yml-must-be-at-least-32-bytes}")
    private String secret;

    @Value("${jwt.expiration-days:7}")
    private long expirationDays;

    private SecretKey key;

    @PostConstruct
    void init() {
        byte[] bytes = secret.getBytes(StandardCharsets.UTF_8);
        if (bytes.length < 32) {
            throw new IllegalStateException("jwt.secret 必须 ≥ 32 字节(HS256 要求)");
        }
        this.key = Keys.hmacShaKeyFor(bytes);
    }

    /** 给 userId 发 token,带 admin RBAC claims。 */
    public String issue(long userId,
                        List<String> permissions,
                        List<String> roleCodes,
                        boolean isSuperAdmin) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(Long.toString(userId))
                .claim("permissions", permissions == null ? Collections.emptyList() : permissions)
                .claim("roleCodes", roleCodes == null ? Collections.emptyList() : roleCodes)
                .claim("isSuperAdmin", isSuperAdmin)
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(expirationDays, ChronoUnit.DAYS)))
                .signWith(key)
                .compact();
    }

    /** 解析失败抛 JwtException。缺失 admin claims 降级为空 / false。 */
    public JwtClaims parseClaims(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        long userId = Long.parseLong(claims.getSubject());
        Instant issuedAt = claims.getIssuedAt() == null ? Instant.now() : claims.getIssuedAt().toInstant();

        Object permsObj = claims.get("permissions");
        @SuppressWarnings("unchecked")
        List<String> permissions = permsObj instanceof List ? (List<String>) permsObj : Collections.emptyList();

        Object rolesObj = claims.get("roleCodes");
        @SuppressWarnings("unchecked")
        List<String> roleCodes = rolesObj instanceof List ? (List<String>) rolesObj : Collections.emptyList();

        Boolean isSuper = claims.get("isSuperAdmin", Boolean.class);
        boolean isSuperAdmin = isSuper != null && isSuper;

        return new JwtClaims(userId, issuedAt, permissions, roleCodes, isSuperAdmin);
    }

    /** 取出 token 的 iat (签发时间)。失败抛 JwtException。用于 AdminAuthInterceptor 校验时效。 */
    public Instant parseIssuedAt(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return claims.getIssuedAt() == null ? Instant.now() : claims.getIssuedAt().toInstant();
    }

    /** 解析出来的全部 claims。 */
    public record JwtClaims(long userId,
                            Instant issuedAt,
                            List<String> permissions,
                            List<String> roleCodes,
                            boolean isSuperAdmin) {}
}
