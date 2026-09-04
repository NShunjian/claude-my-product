package com.qingzhang.common;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.util.LinkedHashMap;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * 005 Java 后端 — ApiResponse 信封结构 + 序列化测试
 *
 * 覆盖目标(005-java-backend.md §3.1):
 *   - ok(data):code=0, message="ok", data 字段透传
 *   - ok():code=0, message="ok", data=null,且 NON_NULL 序列化时不输出 data
 *   - fail(code, msg):code != 0, message=msg, data=null
 *   - JSON 序列化形如 { "code":0, "message":"ok", "data":... }
 *   - 反序列化能拿到 code/message/data 三个字段
 *
 * 工具:JUnit 5 + AssertJ + Jackson
 */
class ApiResponseTest {

    private final ObjectMapper om = new ObjectMapper();

    @Test
    @DisplayName("ok(data) — code=0, message='ok', data 字段透传")
    void okWithData() {
        Map<String, String> payload = new LinkedHashMap<>();
        payload.put("id", "abc-123");
        payload.put("name", "微信支付");

        ApiResponse<Map<String, String>> resp = ApiResponse.ok(payload);

        assertThat(resp.code()).isEqualTo(0);
        assertThat(resp.message()).isEqualTo("ok");
        assertThat(resp.data()).isSameAs(payload);
    }

    @Test
    @DisplayName("ok() 无 data — data=null")
    void okWithoutData() {
        ApiResponse<Void> resp = ApiResponse.ok();

        assertThat(resp.code()).isEqualTo(0);
        assertThat(resp.message()).isEqualTo("ok");
        assertThat(resp.data()).isNull();
    }

    @Test
    @DisplayName("fail(code, message) — code != 0, data=null")
    void failEnvelope() {
        ApiResponse<Void> resp = ApiResponse.fail(3001, "账户不存在");

        assertThat(resp.code()).isEqualTo(3001);
        assertThat(resp.message()).isEqualTo("账户不存在");
        assertThat(resp.data()).isNull();
    }

    @Test
    @DisplayName("JSON 序列化 ok(data) → 含 code/message/data 三字段")
    void jsonOkWithData() throws Exception {
        String json = om.writeValueAsString(ApiResponse.ok("hello"));

        assertThat(json).contains("\"code\":0");
        assertThat(json).contains("\"message\":\"ok\"");
        assertThat(json).contains("\"data\":\"hello\"");
    }

    @Test
    @DisplayName("JSON 序列化 ok() → 含 code/message,不含 data(NON_NULL)")
    void jsonOmitsNullData() throws Exception {
        String json = om.writeValueAsString(ApiResponse.ok());

        assertThat(json).contains("\"code\":0");
        assertThat(json).contains("\"message\":\"ok\"");
        assertThat(json).doesNotContain("\"data\"");
    }

    @Test
    @DisplayName("JSON 序列化 fail → 含 code/message,不含 data")
    void jsonFailEnvelope() throws Exception {
        String json = om.writeValueAsString(ApiResponse.fail(3015, "日期格式非法"));

        assertThat(json).contains("\"code\":3015");
        assertThat(json).contains("\"message\":\"日期格式非法\"");
        assertThat(json).doesNotContain("\"data\"");
    }

    @Test
    @DisplayName("反序列化 — 拿回 code/message/data 三字段")
    void deserializeEnvelope() throws Exception {
        String json = "{\"code\":0,\"message\":\"ok\",\"data\":{\"id\":\"u1\",\"name\":\"alice\"}}";

        var resp = om.readValue(json, ApiResponse.class);

        assertThat(resp.code()).isEqualTo(0);
        assertThat(resp.message()).isEqualTo("ok");
        assertThat(resp.data()).isInstanceOf(java.util.LinkedHashMap.class);
        var dataMap = (java.util.LinkedHashMap<?, ?>) resp.data();
        assertThat(dataMap.get("id")).isEqualTo("u1");
        assertThat(dataMap.get("name")).isEqualTo("alice");
    }

    @Test
    @DisplayName("反序列化失败响应 — code 透传")
    void deserializeFailEnvelope() throws Exception {
        String json = "{\"code\":3017,\"message\":\"账户不在当前账本\"}";

        var resp = om.readValue(json, ApiResponse.class);

        assertThat(resp.code()).isEqualTo(3017);
        assertThat(resp.message()).isEqualTo("账户不在当前账本");
        assertThat(resp.data()).isNull();
    }
}