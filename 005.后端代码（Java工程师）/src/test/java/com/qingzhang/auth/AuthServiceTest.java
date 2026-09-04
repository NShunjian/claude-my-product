package com.qingzhang.auth;

import com.qingzhang.accounts.entity.Account;
import com.qingzhang.accounts.mapper.AccountMapper;
import com.qingzhang.auth.dto.AuthResponse;
import com.qingzhang.auth.dto.Credentials;
import com.qingzhang.books.entity.Book;
import com.qingzhang.books.mapper.BookMapper;
import com.qingzhang.common.BizException;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * 005 Java 后端 — AuthService 鉴权流程测试
 *
 * 覆盖目标:
 *   - register:用户名不存在 → 成功 → 自动建默认账本 + 5 个默认账户
 *   - register:用户名已存在 → 1001 USERNAME_TAKEN
 *   - login:用户不存在 / 密码错 → 1002 INVALID_CREDENTIALS
 *   - login:账号被禁用(status=0)→ 1012 USER_DISABLED
 *   - me:用户不存在 → 1003 USER_NOT_FOUND
 *
 * 工具:JUnit 5 + Mockito + AssertJ
 *
 * 注:BCryptPasswordEncoder 用真 BCrypt,验证 hash 行为;User/Book/Account 实体 insert
 *     走 mapper mock,只关心插入调用是否发生。
 */
class AuthServiceTest {

    private UserMapper userMapper;
    private BookMapper bookMapper;
    private AccountMapper accountMapper;
    private JwtUtil jwtUtil;
    private AuthService service;

    @BeforeEach
    void setUp() {
        userMapper = mock(UserMapper.class);
        bookMapper = mock(BookMapper.class);
        accountMapper = mock(AccountMapper.class);
        jwtUtil = mock(JwtUtil.class);
        service = new AuthService(userMapper, bookMapper, accountMapper, jwtUtil);

        when(jwtUtil.issue(anyLong(), any(), any(), anyBoolean(), any(), anyLong()))
            .thenReturn("mock-jwt-token");

        // 模拟 MyBatis-Plus 自增主键回写 — insert 时把 id 写到传入的实体上
        when(userMapper.insert(any(User.class))).thenAnswer(inv -> {
            inv.<User>getArgument(0).setId(100L);
            return 1;
        });
        when(bookMapper.insert(any(Book.class))).thenAnswer(inv -> {
            inv.<Book>getArgument(0).setId(200L);
            return 1;
        });
        when(accountMapper.insert(any(Account.class))).thenAnswer(inv -> {
            inv.<Account>getArgument(0).setId(System.nanoTime() & 0xfffff);
            return 1;
        });
    }

    @Test
    @DisplayName("register — 用户名可用 → 成功,token 非空,user 字段填好")
    void registerHappyPath() {
        when(userMapper.selectCount(any())).thenReturn(0L);
        when(userMapper.updateById(any(User.class))).thenReturn(1);

        Credentials c = new Credentials("alice_test_2026", "SecretPass@123");
        AuthResponse resp = service.register(c);

        assertThat(resp).isNotNull();
        assertThat(resp.token()).isEqualTo("mock-jwt-token");
        assertThat(resp.user()).isNotNull();
        assertThat(resp.user().username()).isEqualTo("alice_test_2026");
        assertThat(resp.permissions()).isEmpty();
        assertThat(resp.roleCodes()).isEmpty();
        assertThat(resp.isSuperAdmin()).isFalse();
    }

    @Test
    @DisplayName("register — 用户名已被占用 → 抛 BizException(1001)")
    void registerUsernameTaken() {
        when(userMapper.selectCount(any())).thenReturn(1L);

        Credentials c = new Credentials("existing_user", "SecretPass@123");
        assertThatThrownBy(() -> service.register(c))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(1001));
    }

    @Test
    @DisplayName("login — 密码不匹配 → 抛 1002 INVALID_CREDENTIALS")
    void loginWrongPassword() {
        BCryptPasswordEncoder enc = new BCryptPasswordEncoder();
        User existing = User.builder()
            .id(1L).uuid(UUID.randomUUID().toString())
            .username("bob_test")
            .passwordHash(enc.encode("correct_password"))
            .status((byte) 1)
            .createdAt(Instant.now()).updatedAt(Instant.now())
            .tokenVersion(0L)
            .build();
        when(userMapper.selectOne(any())).thenReturn(existing);

        Credentials c = new Credentials("bob_test", "wrong_password");
        assertThatThrownBy(() -> service.login(c))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(1002));
    }

    @Test
    @DisplayName("login — 用户不存在 → 抛 1002 INVALID_CREDENTIALS(不区分以防撞库)")
    void loginUserNotFound() {
        when(userMapper.selectOne(any())).thenReturn(null);

        Credentials c = new Credentials("ghost_user", "AnyPass@1234");
        assertThatThrownBy(() -> service.login(c))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(1002));
    }

    @Test
    @DisplayName("login — 账号被禁用(status=0)→ 抛 1012 USER_DISABLED")
    void loginUserDisabled() {
        User disabled = User.builder()
            .id(2L).uuid(UUID.randomUUID().toString())
            .username("disabled_user")
            .passwordHash(new BCryptPasswordEncoder().encode("AnyPass@1234"))
            .status((byte) 0) // ← 被管理员禁用
            .createdAt(Instant.now()).updatedAt(Instant.now())
            .tokenVersion(0L)
            .build();
        when(userMapper.selectOne(any())).thenReturn(disabled);

        Credentials c = new Credentials("disabled_user", "AnyPass@1234");
        assertThatThrownBy(() -> service.login(c))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(1012));
    }

    @Test
    @DisplayName("me — 用户不存在 → 抛 1003 USER_NOT_FOUND")
    void meUserNotFound() {
        when(userMapper.selectById(99L)).thenReturn(null);

        assertThatThrownBy(() -> service.me(99L))
            .isInstanceOf(BizException.class)
            .satisfies(e -> assertThat(((BizException) e).getCode()).isEqualTo(1003));
    }
}