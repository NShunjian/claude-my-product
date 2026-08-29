package com.qingzhang.users;

import com.qingzhang.auth.JwtAuthFilter;
import com.qingzhang.auth.dto.UserDTO;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import com.qingzhang.common.ErrorCode;
import com.qingzhang.users.dto.ChangePasswordRequest;
import com.qingzhang.users.dto.UpdateProfileRequest;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * /api/users/me 全权处理用户域业务(spec §5.3:10xx 归用户模块)。
 *
 *   GET    /api/users/me            -> UserDTO
 *   PATCH  /api/users/me            -> UserDTO
 *   POST   /api/users/me/password   -> {ok:true}
 *
 * AuthController.me() 是 /api/auth/me 的 read-only 薄别名,委托到这里。
 */
@RestController
@RequestMapping("/api/users")
public class UsersController {

    private final UsersService service;

    public UsersController(UsersService service) {
        this.service = service;
    }

    @org.springframework.web.bind.annotation.GetMapping("/me")
    public ApiResponse<UserDTO> me(HttpServletRequest req) {
        return ApiResponse.ok(service.getMe(userId(req)));
    }

    @PatchMapping("/me")
    public ApiResponse<UserDTO> updateMe(HttpServletRequest req,
                                         @Valid @RequestBody UpdateProfileRequest body) {
        return ApiResponse.ok(service.updateProfile(userId(req), body));
    }

    @PostMapping("/me/password")
    public ApiResponse<Map<String, Object>> changePassword(HttpServletRequest req,
                                                           @Valid @RequestBody ChangePasswordRequest body) {
        service.changePassword(userId(req), body);
        return ApiResponse.ok(Map.of("ok", true));
    }

    private static long userId(HttpServletRequest req) {
        Long id = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (id == null) {
            throw new BizException(ErrorCode.UNAUTHORIZED, "未登录");
        }
        return id;
    }
}
