package com.qingzhang.users;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.qingzhang.auth.dto.UserDTO;
import com.qingzhang.common.BizException;
import com.qingzhang.users.dto.ChangePasswordRequest;
import com.qingzhang.users.dto.UpdateProfileRequest;
import com.qingzhang.users.entity.User;
import com.qingzhang.users.mapper.UserMapper;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;

/**
 * 用户域业务 —— /api/users/me 全权处理。
 * Auth 模块复用这里的 me()。spec §1.2。
 */
@Service
public class UsersService {

    private static final int CODE_USER_NOT_FOUND   = 1003;
    private static final int CODE_INVALID_CREDENTIALS = 1002;
    private static final int CODE_SAME_PASSWORD    = 1004;

    private final UserMapper userMapper;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();

    public UsersService(UserMapper userMapper) {
        this.userMapper = userMapper;
    }

    public UserDTO getMe(long userId) {
        User u = userMapper.selectById(userId);
        if (u == null) {
            throw new BizException(CODE_USER_NOT_FOUND, "用户不存在");
        }
        return toDto(u);
    }

    @Transactional(rollbackFor = Exception.class)
    public UserDTO updateProfile(long userId, UpdateProfileRequest req) {
        User u = userMapper.selectById(userId);
        if (u == null) {
            throw new BizException(CODE_USER_NOT_FOUND, "用户不存在");
        }
        // 部分更新:null 字段不动(spec §3.3)
        if (req.displayName() != null) u.setDisplayName(req.displayName());
        if (req.avatar() != null)      u.setAvatar(req.avatar());
        if (req.gender() != null)       u.setGender(req.gender());
        if (req.age() != null)          u.setAge(req.age());
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);
        return toDto(u);
    }

    @Transactional(rollbackFor = Exception.class)
    public void changePassword(long userId, ChangePasswordRequest req) {
        User u = userMapper.selectById(userId);
        if (u == null) {
            throw new BizException(CODE_USER_NOT_FOUND, "用户不存在");
        }
        if (!encoder.matches(req.oldPassword(), u.getPasswordHash())) {
            throw new BizException(CODE_INVALID_CREDENTIALS, "原密码不正确");
        }
        if (encoder.matches(req.newPassword(), u.getPasswordHash())) {
            throw new BizException(CODE_SAME_PASSWORD, "新密码不能与原密码相同");
        }
        u.setPasswordHash(encoder.encode(req.newPassword()));
        u.setUpdatedAt(Instant.now());
        userMapper.updateById(u);
    }

    /** 暴露给 Auth 模块的共享 mapper 引用,避免重复查询。 */
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

    /** Auth 模块 register/login 用,需在 transaction 内返回带 id 的实体。 */
    public User findByUsername(String username) {
        return userMapper.selectOne(Wrappers.<User>lambdaQuery().eq(User::getUsername, username));
    }
}
