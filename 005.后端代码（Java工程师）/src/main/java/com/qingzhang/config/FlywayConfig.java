package com.qingzhang.config;

import com.baomidou.dynamic.datasource.DynamicRoutingDataSource;
import org.flywaydb.core.Flyway;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private static final Logger log = LoggerFactory.getLogger(FlywayConfig.class);

    @Bean
    public Flyway masterFlyway(@Qualifier("dataSource") DataSource routingDs) {
        DataSource masterDs = ((DynamicRoutingDataSource) routingDs).getDataSource("master");
        Flyway fw = Flyway.configure()
                .dataSource(masterDs)
                .locations("classpath:db/migration")
                .baselineOnMigrate(true)
                .table("flyway_schema_history")
                .load();
        if (Boolean.getBoolean("qz.flyway.repair")) {
            // 一次性:修本地 SQL 与 flyway_schema_history 里的 checksum 不一致。
            // 启动时用 -Dqz.flyway.repair=true 触发,跑通后此 flag 可移除,这段代码保留作为兜底。
            log.warn("qz.flyway.repair=true: 强制 repair,会静默接受 checksum mismatch,慎用");
            fw.repair();
        }
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
        if (Boolean.getBoolean("qz.flyway.repair")) {
            log.warn("qz.flyway.repair=true: 强制 repair,会静默接受 checksum mismatch,慎用");
            fw.repair();
        }
        fw.migrate();
        return fw;
    }
}
