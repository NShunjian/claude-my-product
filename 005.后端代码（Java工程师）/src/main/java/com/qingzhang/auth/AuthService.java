package com.qingzhang.auth;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.auth.dto.AuthResponse;
import com.qingzhang.auth.dto.Credentials;
import com.qingzhang.auth.dto.UserDTO;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

/**
 * 注册/登录/me 业务(DB 持久化版)。
 *
 * 错误码区间:10xx(用户模块,见 ErrorCode / 模块常量)。
 */
@Service
public class AuthService {

    private static final int CODE_USERNAME_TAKEN     = 1001;
    private static final int CODE_INVALID_CREDENTIALS = 1002;
    private static final int CODE_USER_NOT_FOUND      = 1003;

    private final UserMapper userMapper;
    private final BookMapper bookMapper;
    private final JwtUtil jwtUtil;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public AuthService(UserMapper userMapper, BookMapper bookMapper, JwtUtil jwtUtil) {
        this.userMapper = userMapper;
        this.bookMapper = bookMapper;
        this.jwtUtil = jwtUtil;
    }

    @Transactional(rollbackFor = Exception.class)
    public AuthResponse register(Credentials c) {
        Long existing = userMapper.selectCount(
                Wrappers.<User>lambdaQuery()
                        .eq(User::getUsername, c.username())
        );
        if (existing != null && existing > 0) {
            throw new BizException(CODE_USERNAME_TAKEN, "用户名已被占用");
        }
        Instant now = Instant.now();
        User u = User.builder()
                .uuid(UUID.randomUUID().toString())
                .username(c.username())
                .passwordHash(encoder.encode(c.password()))
                .status((byte) 1)
                .createdAt(now)
                .updatedAt(now)
                .build();
        userMapper.insert(u);
        // 注册即开默认账本(spec PRD V1.0.1 §5.2:V1.0 每用户一个个人账本)
        Book defaultBook = Book.builder()
                .uuid(UUID.randomUUID().toString())
                .ownerId(u.getId())
                .name("个人账本")
                .description("默认个人账本")
                .type("personal")
                .currency("CNY")
                .isDefault((byte) 1)
                .isArchived((byte) 0)
                .sortOrder(0)
                .createdAt(now)
                .updatedAt(now)
                .build();
        bookMapper.insert(defaultBook);
        String token = jwtUtil.issue(u.getId());
        return new AuthResponse(toDto(u), token);
    }

    public AuthResponse login(Credentials c) {
        User u = userMapper.selectOne(
                Wrappers.<User>lambdaQuery()
                        .eq(User::getUsername, c.username())
        );
        if (u == null || !encoder.matches(c.password(), u.getPasswordHash())) {
            throw new BizException(CODE_INVALID_CREDENTIALS, "用户名或密码错误");
        }
        // best-effort 更新最近登录时间(失败也不影响登录)
        try {
            u.setLastLoginAt(Instant.now());
            userMapper.updateById(u);
        } catch (Exception ignored) {}
        String token = jwtUtil.issue(u.getId());
        return new AuthResponse(toDto(u), token);
    }

    public UserDTO me(long userId) {
        User u = userMapper.selectById(userId);
        if (u == null) {
            throw new BizException(CODE_USER_NOT_FOUND, "用户不存在");
        }
        return toDto(u);
    }

    public UserDTO toDto(User u) {
        return new UserDTO(
                u.getId(),
                u.getUuid(),
                u.getUsername(),
                u.getDisplayName(),
                u.getAvatar(),
                u.getGender(),
                u.getAge(),
                u.getCreatedAt()
        );
    }
}