package com.qingzhang.config;

import com.fasterxml.jackson.core.JsonGenerator;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.springframework.boot.autoconfigure.jackson.Jackson2ObjectMapperBuilderCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * V1.2 金额核算审计:BigDecimal 序列化 / 反序列化明确化。
 *
 * 两个关键点:
 *   1. WRITE_BIGDECIMAL_AS_PLAIN —— 序列化时用 toPlainString,禁止科学计数法。
 *      对 number 输出同样生效(plain 形式如 10000.00 而非 1E+4)。
 *   2. USE_BIG_DECIMAL_FOR_FLOATS —— 反序列化时,JSON number → BigDecimal 而非 Double,
 *      防止 IEEE-754 精度损失。
 *
 * V1.2.1 修正(2026-09-11):移除 ToStringSerializer 兜底序列化器。原配置把所有
 *   BigDecimal 序列化为 JSON string("10000.00"),前端 type 声明是 number,
 *   `Number.isFinite(string) === false` → formatAmount 返回 `--`,流水/账户
 *   全部金额不显示。DECIMAL(12,2) 边界保护精度,number 输出完全无精度损失
 *   (整数位 10 / 小数位 2 ≤ 2^53),改回 Jackson 默认 number 序列化。
 *
 * 关键修正(2026-09-11):
 *   - 删掉多余的 @Bean ObjectMapper。之前两个 @Bean 同时存在时,ObjectMapper 会
 *     **覆盖** Spring Boot 自动配置的 Jackson2ObjectMapperBuilder,导致
 *     JavaTimeModule 不被注册,Instant / LocalDateTime 序列化失败(用户登录
 *     报 code:1500 "服务器开小差")。保留一个 customizer 即可,让 Spring Boot
 *     的 builder 自己处理模块发现 + 默认特性。
 *   - 显式声明 JavaTimeModule 依赖,避免 SPI 失败时再次出现时间序列化坑。
 */
@Configuration
public class JacksonConfig {

    @Bean
    public Jackson2ObjectMapperBuilderCustomizer moneyAuditCustomizer() {
        return builder -> builder
                .modulesToInstall(new JavaTimeModule())
                .featuresToEnable(JsonGenerator.Feature.WRITE_BIGDECIMAL_AS_PLAIN)
                .featuresToEnable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS);
        // ponytail: 不再 serializerByType(BigDecimal.class, ToStringSerializer.instance) —
        //          Jackson 默认 number 序列化 + WRITE_BIGDECIMAL_AS_PLAIN 已覆盖精度保护。
    }
}
