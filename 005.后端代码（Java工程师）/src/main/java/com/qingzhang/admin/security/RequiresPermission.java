package com.qingzhang.admin.security;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 声明一个 admin handler 方法所需的权限码 (例如 "user:list")。
 *
 * 仅对带 @RequiresPermission 的方法生效 —— 缺省时 AdminAuthInterceptor
 * 只检查"是否至少有 1 个 admin 角色",不要求具体权限。
 *
 * super_admin 角色绕过所有权限检查(等同全部许可)。
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface RequiresPermission {
    /** 资源:动作 形式的权限码,如 "user:list"、"category:preset:create"。 */
    String value();
}
