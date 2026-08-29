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
import java.util.Date;

/**
 * HS256 JWT。密钥从 application.yml 的 jwt.secret 读,默认 7 天过期。
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

    /** 给 userId 发 token。subject 直接放 userId 字符串。 */
    public String issue(long userId) {
        Instant now = Instant.now();
        return Jwts.builder()
                .subject(Long.toString(userId))
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(expirationDays, ChronoUnit.DAYS)))
                .signWith(key)
                .compact();
    }

    /** 解析失败抛 JwtException,由 controller/filter 决定映射。 */
    public long parseSubject(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return Long.parseLong(claims.getSubject());
    }
}
