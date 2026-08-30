package com.qingzhang.admin.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableLogic;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.time.Instant;

/**
 * 后台管理员账号实体(admin_users) —— MyBatis-Plus。
 *
 * 与 User 的区别:
 *   - 独立表 admin_users(AUTO_INCREMENT 从 1000 起),不再与普通用户共享 users
 *   - 增加 mfaSecret / passwordExpiresAt 预留字段(V1.1 接 UI)
 *   - 没有 avatar/gender/age/email/phone —— admin 不需要这些
 *
 * 登录路径:/api/admin/auth/login(admin-only,不与 /api/auth/login 互通)
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@TableName("admin_users")
public class AdminUser {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String uuid;

    private String username;

    /** BCrypt 哈希。前端不返。 */
    private String passwordHash;

    private String displayName;

    /** 1=启用 0=禁用 */
    private Byte status;

    private Instant lastLoginAt;

    private String lastLoginIp;

    /** V1.1 预留:TOTP secret */
    private String mfaSecret;

    /** V1.1 预留:密码过期时间 */
    private Instant passwordExpiresAt;

    /** 每次账号状态 / 角色变更自增;JWT 内 token_version 必须等于该字段,否则视为过期。
     *  0 表示尚未启用 token 失效机制(老 token 兜底放行)。 */
    private Long tokenVersion;

    private Instant createdAt;

    private Instant updatedAt;

    @TableLogic
    @TableField(select = false)
    private Instant deletedAt;
}