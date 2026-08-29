package com.qingzhang.auth.dto;

/**
 * /api/auth/register 与 /api/auth/login 直接返回此形状(走 ApiResponse 包装都不包):
 *   { "user": {...}, "token": "..." }
 * 前端 src/api/auth.ts 的 AuthResponse 严格对齐此形状。
 */
public record AuthResponse(UserDTO user, String token) {}
