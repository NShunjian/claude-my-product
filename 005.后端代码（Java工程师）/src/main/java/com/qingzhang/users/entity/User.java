package com.qingzhang.users.entity;

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
 * 用户表(users)实体 —— MyBatis-Plus。
 *
 * spec §6.1:@TableLogic + @TableField(fill=...) 配合 global-config.db-config 即可。
 */
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
@TableName("users")
public class User {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String uuid;

    private String username;

    /** BCrypt 哈希。前端不返。 */
    private String passwordHash;

    private String displayName;

    private String avatar;

    /** male / female / other */
    private String gender;

    private Integer age;

    private String email;

    private String phone;

    private Byte status;

    private Instant lastLoginAt;

    private String lastLoginIp;

    private Instant createdAt;

    private Instant updatedAt;

    @TableLogic
    @TableField(select = false)
    private Instant deletedAt;
}
