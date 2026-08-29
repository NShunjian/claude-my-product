package com.qingzhang;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;

/**
 * ponytail: DB 尚未接入,排除 DataSourceAutoConfiguration 避免 mysql-connector-j 触发自动配置失败;
 * 接入 Flyway/DB 时去掉这一行 exclude 并补 datasource 配置。
 */
@SpringBootApplication(exclude = DataSourceAutoConfiguration.class)
public class QingZhangApplication {

    public static void main(String[] args) {
        SpringApplication.run(QingZhangApplication.class, args);
    }
}
