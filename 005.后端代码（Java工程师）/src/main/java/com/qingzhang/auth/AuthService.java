package com.qingzhang.auth;

import com.qingzhang.auth.dto.AuthResponse;
import com.qingzhang.auth.dto.Credentials;
import com.qingzhang.auth.dto.UserDTO;
import com.qingzhang.common.BizException;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 内存用户存 + 注册/登录/me 业务。
 *
 * ponytail: ConcurrentHashMap 临时兜底;接 MySQL 后这个 map 替换成 UserMapper,
 * 业务方法签名保持稳定,controller 不动。
 */
@Service
public class AuthService {

    private record UserRow(long id,
                           String uuid,
                           String username,
                           String displayName,
                           String avatar,
                           String gender,
                           Integer age,
                           Instant createdAt,
                           String passwordHash) {}

    /** 业务码区间:10xx 用户模块。 */
    private static final int CODE_USERNAME_TAKEN = 1001;
    private static final int CODE_INVALID_CREDENTIALS = 1002;
    private static final int CODE_USER_NOT_FOUND = 1003;

    private final ConcurrentHashMap<String, UserRow> byUsername = new ConcurrentHashMap<>();
    private final AtomicLong idGen = new AtomicLong(1);
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final JwtUtil jwtUtil;

    public AuthService(JwtUtil jwtUtil) {
        this.jwtUtil = jwtUtil;
    }

    public AuthResponse register(Credentials c) {
        String username = c.username();
        if (byUsername.containsKey(username)) {
            throw new BizException(CODE_USERNAME_TAKEN, "用户名已被占用");
        }
        long id = idGen.getAndIncrement();
        Instant now = Instant.now();
        UserRow row = new UserRow(
                id,
                UUID.randomUUID().toString(),
                username,
                null,
                null,
                null,
                null,
                now,
                encoder.encode(c.password())
        );
        byUsername.put(username, row);
        String token = jwtUtil.issue(id);
        return new AuthResponse(toDto(row), token);
    }

    public AuthResponse login(Credentials c) {
        UserRow row = byUsername.get(c.username());
        if (row == null || !encoder.matches(c.password(), row.passwordHash())) {
            throw new BizException(CODE_INVALID_CREDENTIALS, "用户名或密码错误");
        }
        String token = jwtUtil.issue(row.id);
        return new AuthResponse(toDto(row), token);
    }

    public UserDTO me(long userId) {
        UserRow row = byUsername.values().stream()
                .filter(u -> u.id() == userId)
                .findFirst()
                .orElseThrow(() -> new BizException(CODE_USER_NOT_FOUND, "用户不存在"));
        return toDto(row);
    }

    private UserDTO toDto(UserRow row) {
        return new UserDTO(
                row.id(),
                row.uuid(),
                row.username(),
                row.displayName(),
                row.avatar(),
                row.gender(),
                row.age(),
                row.createdAt()
        );
    }
}
