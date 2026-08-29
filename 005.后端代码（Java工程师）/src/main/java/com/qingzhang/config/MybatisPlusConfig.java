package com.qingzhang.config;

import org.springframework.context.annotation.Configuration;

/**
 * MyBatis-Plus 配置占位。
 *
 * ponytail: 3.5.9 已把分页内置到 BaseMapper(Page<T> 参数自动走方言),
 * 不再需要额外注册 PaginationInnerInterceptor(3.5.x 已删除该类)。
 * 字段映射(下划线→驼峰)走 application.yml 全局开关,这里不再重复。
 * 若日后需要乐观锁/动态表名,再加 @Bean MybatisPlusInterceptor。
 */
@Configuration
public class MybatisPlusConfig {
}
