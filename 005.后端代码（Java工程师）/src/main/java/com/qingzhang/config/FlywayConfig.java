package com.qingzhang.config;

import com.baomidou.dynamic.datasource.DynamicRoutingDataSource;
import org.flywaydb.core.Flyway;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import javax.sql.DataSource;

/**
 * 双库各跑一个 Flyway。
 *
 * spring.flyway.enabled=false 关掉 Spring 默认 Flyway。
 * 这里的两个 @Bean 各取 dynamic-datasource 路由表里的 master / admin 真实
 * DataSource,各自 load+migrate。Flyway 必须在 mapper 之前完成,所以
 * 在 @Bean 方法里立刻 migrate() 而非延迟。
 *
 * ponytail: master 与 admin 的 flyway_schema_history 表都叫这个名 —— 各自
 * 在自己的 schema 下,不冲突。
 */
@Configuration
public class FlywayConfig {

    @Bean
    public Flyway masterFlyway(@Qualifier("dataSource") DataSource routingDs) {
        DataSource masterDs = ((DynamicRoutingDataSource) routingDs).getDataSource("master");
        Flyway fw = Flyway.configure()
                .dataSource(masterDs)
                .locations("classpath:db/migration")
                .baselineOnMigrate(true)
                .table("flyway_schema_history")
                .load();
        fw.migrate();
        return fw;
    }

    @Bean
    public Flyway adminFlyway(@Qualifier("dataSource") DataSource routingDs) {
        DataSource adminDs = ((DynamicRoutingDataSource) routingDs).getDataSource("admin");
        Flyway fw = Flyway.configure()
                .dataSource(adminDs)
                .locations("classpath:db/migration-admin")
                .baselineOnMigrate(true)
                .table("flyway_schema_history")
                .load();
        fw.migrate();
        return fw;
    }
}
