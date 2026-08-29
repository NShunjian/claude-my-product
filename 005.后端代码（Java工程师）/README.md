# 轻账 — Java 后端骨架(0.0.1-SNAPSHOT)

为「轻账」提供 API。技术栈:**Spring Boot 3.5 + JDK 26 + Maven + MyBatis-Plus**(其余模块按需补)。

## 当前状态(本轮)

- 工程骨架可编译可启动
- 一个烟雾接口:`GET /api/v1/version` → `{code:0,message:"ok",data:{name,version}}`
- 统一响应包络 `ApiResponse<T>` + 业务异常 + 全局异常处理

尚未接入(下一轮做):DB / Flyway / MyBatis-Plus 实体与 Mapper / JWT 安全 / 业务接口。

## 运行

```sh
cd "005.后端代码（Java工程师）"
mvn spring-boot:run
# 另开终端:
curl http://localhost:4001/api/v1/version
```

期望:`{"code":0,"message":"ok","data":{"name":"qingzhang-java-backend","version":"0.0.1-SNAPSHOT"}}`

## 与 Node 后端的关系

默认假设为**并行双跑**:Node :4000,Java :4001,共享同一 MySQL,后续接 JWT 时复用同一密钥(token 互通)。如要改成「完全替代」或「只做新业务」,影响的是这一段约定,而不是工程结构。
