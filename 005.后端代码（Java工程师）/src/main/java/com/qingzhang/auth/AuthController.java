package com.qingzhang.auth;

import com.qingzhang.auth.dto.AuthResponse;
import com.qingzhang.auth.dto.Credentials;
import com.qingzhang.auth.dto.UserDTO;
import com.qingzhang.common.ApiResponse;
import com.qingzhang.common.BizException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * /api/auth/* 一律走 ApiResponse 信封(成功 code=0、data=xxx;失败由 GlobalExceptionHandler 兜)。
 *
 *   POST /api/auth/register  {username,password} -> {code:0, data:{user,token}}
 *   POST /api/auth/login     {username,password} -> {code:0, data:{user,token}}
 *   GET  /api/auth/me        Authorization: Bearer .. -> {code:0, data:{user}}
 *   POST /api/auth/logout    -> {code:0, data:{ok:true}}    (JWT 无状态)
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private static final int CODE_UNAUTHORIZED = 1401;

    private final AuthService service;

    public AuthController(AuthService service) {
        this.service = service;
    }

    @PostMapping("/register")
    public ApiResponse<AuthResponse> register(@Valid @RequestBody Credentials body) {
        return ApiResponse.ok(service.register(body));
    }

    @PostMapping("/login")
    public ApiResponse<AuthResponse> login(@Valid @RequestBody Credentials body) {
        return ApiResponse.ok(service.login(body));
    }

    @GetMapping("/me")
    public ApiResponse<UserDTO> me(HttpServletRequest req) {
        Long userId = (Long) req.getAttribute(JwtAuthFilter.USER_ID_ATTR);
        if (userId == null) {
            throw new BizException(CODE_UNAUTHORIZED, "未登录");
        }
        return ApiResponse.ok(service.me(userId));
    }

    @PostMapping("/logout")
    public ApiResponse<Map<String, Object>> logout() {
        return ApiResponse.ok(Map.of("ok", true));
    }
}
