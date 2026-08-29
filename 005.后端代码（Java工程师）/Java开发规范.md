# 轻账 Java 后端 · 开发规范

> 本规范面向「轻账」Java 后端工程 (`005.后端代码(Java工程师)/`),由大厂架构师视角编写,所有团队成员必须遵守。
> 风格基线参考《阿里巴巴 Java 开发手册(泰山版)》+ Spring Boot 官方指南。

---

## 0. 适用范围与原则

- **强制**:标注 [MUST] 的条目,违反一律打回重写。
- **推荐**:标注 [SHOULD] 的条目,合理偏离需在 PR 描述里说明理由。
- **禁止**:标注 [MUST NOT] 的条目,任何理由都不允许。

四大原则:**简单胜于复杂、可读胜于技巧、一致胜于个人偏好、显式胜于隐式**。

---

## 1. 工程结构

### 1.1 模块划分 [MUST]

按 **业务模块垂直切分**,公共能力下沉到 `common`,禁止按层横切(controller 全放一个包)。

```
com.qingzhang
├── QingZhangApplication.java          主类
├── auth/                              鉴权模块:controller / service / dto / util
├── users/                             用户模块
├── books/                             账本模块
├── accounts/                          账户模块
├── categories/                        分类模块
├── records/                           账目模块
├── reports/                           报表模块
├── common/                            跨模块公共:ApiResponse / BizException / ErrorCode
├── config/                            全局配置:MyBatis-Plus / WebMvc / OpenAPI
├── exception/                         GlobalExceptionHandler
├── security/                          JwtFilter / SecurityUtil
└── infra/                             基础设施:cache / oss / mq
```

### 1.2 每个业务模块内部 [MUST]

```
auth/
├── AuthController.java        REST 入口,只做协议转换
├── AuthService.java           业务编排(接口 + 实现分离只在 > 200 行时考虑)
├── AuthRepository.java        MyBatis-Plus BaseMapper 子接口(可选)
├── dto/                       入参 / 出参 record
│   ├── LoginRequest.java
│   └── LoginResponse.java
└── internal/                  模块内部才用的类,禁止外部依赖
```

> 单文件不超过 400 行 [SHOULD];超过必须拆。Controller 不超过 200 行,只做「接参 → 调 service → 包装响应」三件事。

---

## 2. 命名规范

### 2.1 包名 [MUST]

全小写,无下划线,名词:**`com.qingzhang.<业务域>.<角色>`**。例:`com.qingzhang.records.service`。

### 2.2 类名 [MUST]

| 类型 | 命名 | 示例 |
|---|---|---|
| Controller | `XxxController` | `RecordsController` |
| Service | `XxxService` | `RecordsService` |
| Mapper | `XxxMapper` | `RecordsMapper` |
| 实体 | `Xxx`(单数,无 `Entity` 后缀) | `Record` |
| DTO 入参 | `XxxRequest` / `XxxQuery` | `CreateRecordRequest` |
| DTO 出参 | `XxxResponse` / `XxxVO` | `RecordResponse` |
| 工具 | `XxxUtil` / `XxxHelper` | `JwtUtil` |
| 配置 | `XxxConfig` | `MybatisPlusConfig` |
| 枚举 | 单数名词 | `RecordType`,`ErrorCode` |
| 常量类 | `XxxConstants` | `JwtConstants` |

### 2.3 方法名 [MUST]

| 行为 | 命名 |
|---|---|
| 查询单个 | `getById` / `findByXxx`(返回 `Optional` 用 `find`,可能为 null 用 `get`) |
| 查询列表 | `listXxx` / `pageXxx`(分页) |
| 新增 | `createXxx` / `addXxx`(返回新实体) |
| 修改 | `updateXxx`(返回 boolean) |
| 删除 | `deleteXxx` / `removeXxx`(逻辑删除用 `remove`) |
| 校验 | `validateXxx` / `checkXxx`(返回 `boolean`,不抛) |
| 计算 | `calcXxx` / `computeXxx` |
| 异步 | `XxxAsync` 后缀,或单独放 `async` 包 |

### 2.4 变量名 [MUST]

- 禁止单字母(循环变量除外)
- 布尔变量用 `is` / `has` / `can` 前缀:`isDeleted` / `hasPermission`
- 集合用复数:`users` / `recordIds`
- 常量全大写下划线:`MAX_PAGE_SIZE = 200`
- 临时变量 ≤ 3 字符需注释说明用途

### 2.5 数据库 [MUST]

- 表名:`snake_case` 复数,业务前缀:`users` / `records` / `record_attachments`
- 主键:`id BIGINT AUTO_INCREMENT`(统一自增)
- 业务主键(对外):`uuid VARCHAR(36)`,由应用层生成
- 时间字段:`created_at` / `updated_at` / `deleted_at`(逻辑删除)
- 字段名绝不复用 Java 关键字;`desc` → `description`、`class` → `category`

---

## 3. Java 编码规范

### 3.1 基础 [MUST]

- **JDK 版本**:`pom.xml` 锁定 `<java.version>21</java.version>`,业务包禁用过时 API
- **Lombok**:`@Data` 慎用(产生 equals/hashCode/toString 链),优先 `@Getter` `@ToString` `@RequiredArgsConstructor`
- **不可变对象**:**DTO / 出参 / 枚举值一律 `record`**;可变状态才用 class
- **避免 `Optional` 作为字段/参数**,只能作返回值
- **避免 `null` 返回**:列表返回空集合,单个用 `Optional` 或抛 `BizException`

### 3.2 控制流 [MUST]

- `if` / `for` / `while` 必须有花括号,即使一行
- 提前 return / continue,减少嵌套(三层嵌套上限)
- 多 `if-else` 用 `switch` 表达式(JDK 14+);`switch` 必须穷举,带 `default` 兜底

```java
// ✅ 推荐
return switch (type) {
    case INCOME  -> record.getIncome();
    case EXPENSE -> record.getExpense();
};
```

### 3.3 注释 [SHOULD]

- 公共 API(`public` 方法)必须有 Javadoc,**说明 what + why,不重复 how**
- `// TODO` 必须带负责人 + 截止日期:`// TODO(zhangsan, 2026-09-30): 处理退款边界`
- 注释掉的代码**不留**,靠 git 历史
- 临时绕过加 `// ponytail: 临时占位,DB 接入后替换` 这类**带升级路径**的注释

### 3.4 禁止项 [MUST NOT]

- ❌ `System.out.println` / `printStackTrace`(统一走 SLF4J)
- ❌ 捕获异常不处理:`catch (Exception e) {}`
- ❌ 魔法值散落代码里;出现 2 次以上必须抽常量
- ❌ `Thread.sleep` / 死循环 / 随机失败 — 测试用 `Awaitility`
- ❌ 直接 `new Thread()`,并发统一 `Executor` / `@Async`
- ❌ `SimpleDateFormat`(线程不安全),用 `DateTimeFormatter`

---

## 4. Spring Boot 实践

### 4.1 注解 [MUST]

| 场景 | 注解 |
|---|---|
| Controller | `@RestController` + `@RequestMapping("/api/v1/xxx")` |
| 注入 | `@RequiredArgsConstructor` + `final` 字段(**禁用 `@Autowired` 字段注入**) |
| 配置类 | `@Configuration` + `@Bean` |
| 事务 | `@Transactional(rollbackFor = Exception.class)`(默认只回滚 RuntimeException) |
| 缓存 | `@Cacheable` / `@CacheEvict`,key 用 SpEL |
| 异步 | `@Async` + 自定义 `TaskExecutor` |

### 4.2 配置文件 [MUST]

- 用 `application.yml`(非 properties),UTF-8
- 按环境分:`application-{dev|test|prod}.yml`
- 密码 / 密钥 / Token 走环境变量:`${JWT_SECRET}`,**绝不进 git**
- 配置类用 `@ConfigurationProperties(prefix = "xxx")` + `record`(替代 `@Value` 散落)

### 4.3 启动器 [MUST NOT]

- 不要手撸 `RestTemplate` / `OkHttpClient`,统一 `WebClient`(响应式)或新项目用 `RestClient`(3.2+)
- 不要重复造轮子:分页用 MyBatis-Plus `Page`,参数校验用 `spring-boot-starter-validation`

---

## 5. API 设计规范

### 5.1 路径 [MUST]

- 前缀 `/api/v{版本号}`(当前 `v1`)
- 资源用 **复数名词**:`/api/v1/records`、`/api/v1/accounts`
- 不带动词:✅ `POST /records` ❌ `POST /createRecord`
- 嵌套资源一层:`/api/v1/books/{bookId}/members`,二层以上改 query 参数
- 查询过滤走 query,不在路径里:`GET /records?bookId=1&from=2026-01-01`

### 5.2 HTTP 方法 [MUST]

| 操作 | 方法 | 路径 | 幂等 |
|---|---|---|---|
| 列表 | GET | `/xxx` | 是 |
| 详情 | GET | `/xxx/{id}` | 是 |
| 新增 | POST | `/xxx` | 否 |
| 全量改 | PUT | `/xxx/{id}` | 是 |
| 部分改 | PATCH | `/xxx/{id}` | 否 |
| 删除 | DELETE | `/xxx/{id}` | 是 |

### 5.3 响应信封 [MUST]

**统一格式 `ApiResponse<T>`**:

```json
// 成功
{ "code": 0, "message": "ok", "data": { ... } }

// 失败
{ "code": 1001, "message": "用户名已被占用" }
```

- `code`:`int`,`0` = 成功,其它为错误码
- `message`:`String`,人类可读,中文为主
- `data`:成功时承载业务数据,失败时为 `null` / 省略
- 错误码区间:**1xxx** 通用参数 / 鉴权,**10xx** 用户,**20xx** 账本,**30xx** 账目,**40xx** 报表,**9xxx** 系统

### 5.4 分页响应 [MUST]

```json
{
  "code": 0,
  "data": {
    "items": [ ... ],
    "total": 123,
    "page": 1,
    "pageSize": 20
  }
}
```

### 5.5 入参校验 [MUST]

- Controller 入参对象加 `@Valid`
- 字段约束用 JSR-380:`@NotBlank` `@Size` `@Min` `@Max` `@Pattern` `@Email`
- 业务级校验放 Service,**校验失败抛 `BizException(code, msg)`**,由 `GlobalExceptionHandler` 统一返

---

## 6. 数据库与持久层 (MyBatis-Plus)

### 6.1 实体 [MUST]

```java
@Data
@TableName("records")
public class Record {
    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    @TableField(fill = FieldFill.INSERT_UPDATE)
    private Instant updatedAt;

    @TableLogic
    @TableField(select = false)
    private Instant deletedAt;
}
```

### 6.2 Mapper [MUST]

- 继承 `BaseMapper<Entity>`,简单 CRUD 不用写
- 自定义 SQL 用 `@Select` / `@Update` 注解或同包 `xml/EntityMapper.xml`,**不写在 service 里拼字符串**
- 复杂查询分页:**必须**用 `Page<T>` + `PageHelper` 插件,**禁用手写 limit**

### 6.3 Service 层 [MUST]

- 注入 `Mapper` / 其他 `Service`,**禁止跨 Service 调 Mapper**(走 service)
- 事务边界:**只在 Service 方法上加 `@Transactional`**,Controller 不加
- 读写分离:写 `@Transactional(readOnly = false)`,读 `readOnly = true`

### 6.4 字段映射 [MUST]

- DB `snake_case` ↔ Java `camelCase`,**全局开启 mybatis-plus `map-underscore-to-camel-case: true`**
- 时间统一 `Instant`(UTC),展示层转本地时区
- 金额用 `BigDecimal`,**严禁 `double` / `float`**;DB 用 `DECIMAL(18, 2)`

---

## 7. 日志规范

### 7.1 门面 [MUST]

```java
private static final Logger log = LoggerFactory.getLogger(Xxx.class);
```

- 不用 `LoggerFactory.getLogger` 之外的入口
- 输出**结构化字段**而不是拼接字符串:

```java
// ✅ 推荐
log.info("user register success userId={} username={}", id, name);
// ❌ 禁止
log.info("user register success: " + id + ", " + name);
```

### 7.2 级别 [MUST]

| 级别 | 用途 |
|---|---|
| ERROR | 系统异常 / 影响业务的失败;**必须**带堆栈 |
| WARN  | 业务异常 / 鉴权失败 / 重试 |
| INFO  | 关键业务节点(订单创建、支付成功) |
| DEBUG | 调试信息,生产默认关闭 |
| TRACE | 详细链路追踪 |

### 7.3 敏感信息 [MUST NOT]

- ❌ 日志打印:密码、token、身份证、手机号、银行卡(后 6 位可)
- 实在要打:脱敏 `MaskUtil.mobile("13800001234") → "138****1234"`

### 7.4 TraceId [MUST]

- 用 SLF4J MDC:每个请求入口生成 `traceId`(Filter),日志格式 `%X{traceId}`,链路追踪串起来

---

## 8. 异常处理

### 8.1 异常分层 [MUST]

```
BizException(code, msg)        ← 业务异常,可预期,无需堆栈
    ├── 1001 用户名占用
    ├── 1002 凭据错
    └── ...

SystemException                ← 系统异常,不可预期,带堆栈
    ├── DB 连不上
    ├── 外部 API 超时
    └── ...
```

### 8.2 全局处理 [MUST]

- `GlobalExceptionHandler` 用 `@RestControllerAdvice`
- 业务异常 → `ApiResponse.fail(code, msg)`,HTTP 状态 400
- 系统异常 → `ApiResponse.fail(9999, "服务暂不可用")`,HTTP 500,**真实堆栈写 ERROR 日志,不返给前端**
- 校验异常(`MethodArgumentNotValidException`)→ 提取第一条错误信息,code 1000

### 8.3 抛出规则 [MUST]

- Service 抛业务异常,**不返回 `null` / `boolean` 让 Controller 判断**
- 永远不 `catch (Throwable)`,太宽;不 `catch (Exception e) { return null; }`

---

## 9. 安全规范

### 9.1 认证 [MUST]

- 选型:对外 API 用 **JWT(HS256 / RS256)**;内部调用用 **mTLS 或服务签名**
- Token 生命周期:access 2h + refresh 7d(短期 access 降泄露风险)
- 强制 HTTPS(生产);本地 `application-dev.yml` 例外
- JWT 密钥 ≥ 32 字节,从环境变量读,启动时校验

### 9.2 授权 [MUST]

- RBAC:用户-角色-权限三层
- `@PreAuthorize("hasRole('ADMIN')")` / `@PreAuthorize("hasAuthority('record:write')")`
- 数据级权限(用户只能看自己账本):**MyBatis-Plus 多租户插件** 或 SQL 强制拼 `where user_id = ?`

### 9.3 输入 [MUST]

- 所有用户输入 **服务端二次校验**(前端校验只用于 UX)
- SQL 用参数绑定(`#{xxx}`),**严禁字符串拼接**
- 富文本输出转义;URL 参数白名单
- 文件上传:校验 MIME、扩展名、大小

### 9.4 依赖 [MUST]

- 引入第三方前查 `https://snyk.io` 或阿里云镜像的漏洞库
- 关键依赖(lombok / jjwt / mysql-connector)锁版本

---

## 10. 配置管理

### 10.1 配置分层 [MUST]

```
application.yml          公共配置(应用名 / 端口 / 启用的 profile)
application-dev.yml      开发
application-test.yml     测试
application-prod.yml     生产(由部署系统注入,不入 git)
```

### 10.2 密钥管理 [MUST NOT]

- ❌ 密钥 / 密码 / 私钥 / 证书 写进 yml 进 git
- ✅ 用 环境变量 / 配置中心(Nacos / Apollo / Vault)
- ✅ 启动时校验必填密钥缺失即 fail-fast

### 10.3 动态配置 [SHOULD]

- 经常改的(限流阈值、白名单)走配置中心,不发版生效
- 不改的(端口、连接池大小)留 yml

---

## 11. 测试规范

### 11.1 测试金字塔 [MUST]

```
        /\
       /  \        E2E(Playwright,只在核心链路少量)
      /────\
     /      \      集成测试(@SpringBootTest + Testcontainers,覆盖 service / repository)
    /────────\
   /          \    单元测试(JUnit 5 + Mockito,覆盖 service / util,行覆盖 ≥ 70%)
  /────────────\
```

### 11.2 单元测试 [MUST]

- 命名:`methodName_条件_期望结果` → `register_whenUsernameTaken_throwsBizException`
- AAA 结构(Arrange / Act / Assert),每个测试只断一个断言
- Mock 边界,**不 mock 自己写的类**
- 业务异常用 `assertThrows(BizException.class, () -> ...)`

### 11.3 集成测试 [MUST]

- 用 **Testcontainers MySQL**(不 mock 数据库)
- `application-test.yml` 指向容器,跑完销毁
- 测试间隔离:`@Transactional` + `@Sql` 脚本回滚 / 每个测试方法独立容器

### 11.4 覆盖率 [MUST]

- 新增代码:`instruction coverage ≥ 80%`、`branch coverage ≥ 60%`
- CI 阶段强制,低于阈值 block merge

---

## 12. Git 与提交规范

### 12.1 分支策略 [MUST]

```
main              ← 生产就绪,tag 标记版本,受保护
  └─ develop      ← 集成分支
       ├─ feat/xxx
       ├─ fix/xxx
       └─ refactor/xxx
```

- `feat/*` → `develop` → PR review → squash merge
- `hotfix/*` → `main` + `develop`,紧急修复通道
- **禁止**直接 push `main`

### 12.2 提交信息 [MUST]

**Conventional Commits**:

```
<type>(<scope>): <subject>

<body>

<footer>
```

| type | 用途 |
|---|---|
| feat | 新功能 |
| fix | 修复 |
| refactor | 重构(既非 feat 也非 fix) |
| perf | 性能优化 |
| test | 仅测试 |
| docs | 仅文档 |
| chore | 杂项(依赖、配置) |

示例:`feat(records): 支持按月汇总报表`

### 12.3 PR Checklist [MUST]

- [ ] 编译通过,无新警告
- [ ] 单测覆盖新逻辑
- [ ] 自测烟测通过
- [ ] 无新增 `// TODO` / 调试代码
- [ ] 涉及 schema 改动同步 DBA
- [ ] 涉及 API 改动同步前端
- [ ] 描述里说明「为什么」和「影响范围」

---

## 13. 可观测性

### 13.1 指标 [MUST]

- 引入 `micrometer-registry-prometheus`,启用 `/actuator/prometheus`
- 关键指标:QPS、P99 延迟、错误率、JVM、连接池、Hikari 活跃数

### 13.2 健康检查 [MUST]

- `/actuator/health` 暴露 DB / Redis / 外部依赖健康状态
- 接入 K8s liveness / readiness probe

### 13.3 链路追踪 [SHOULD]

- 接入 OpenTelemetry 或 SkyWalking
- HTTP / JDBC / Redis 自动埋点
- 业务日志带 `traceId`,与 trace 系统打通

---

## 14. Code Review Checklist

每次 PR 评审按此顺序扫:

| 优先级 | 检查项 |
|---|---|
| 🔴 必须 | 是否引入安全漏洞(注入、越权、敏感泄露) |
| 🔴 必须 | 是否破坏现有 API 合同 / 数据库 schema |
| 🔴 必须 | 是否有未处理异常 / 空指针风险 |
| 🟡 重要 | 是否符合本规范的命名、分层、注释要求 |
| 🟡 重要 | 是否有重复代码(可抽取) |
| 🟡 重要 | 单元测试是否充分,边界用例覆盖 |
| 🟢 建议 | 性能 / 可读性 / 一致性 |

---

## 附录 A:工程初始化清单(新模块)

- [ ] `pom.xml` 引入依赖,锁定版本
- [ ] 包结构按 §1.2 创建
- [ ] 实体 + Mapper(继承 `BaseMapper`)
- [ ] DTO(用 `record`,加 JSR-380 校验)
- [ ] Service(接口继承 `IService<T>`?)
- [ ] Controller(`@RestController` + `/api/v1/...`)
- [ ] 业务异常码(填入 `ErrorCode` 或模块内常量)
- [ ] 单测:`XxxServiceTest`(覆盖率 ≥ 80%)
- [ ] 集成测:`XxxControllerIT`(Testcontainers)
- [ ] OpenAPI 注解(`@Operation` `@Tag`)
- [ ] README 章节(端点列表 + curl 示例)

---

## 附录 B:参考资料

- 《阿里巴巴 Java 开发手册(泰山版)》— 国内事实标准
- [Spring Boot Reference](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/)
- [MyBatis-Plus 官方文档](https://baomidou.com/)
- [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html) — 命名与格式基线
- 《Effective Java》(Joshua Bloch, 3rd Edition)
- 《Clean Code》(Robert C. Martin)

---

> **变更控制**:本规范变更需经架构组评审,提交 PR 到 `main`,评审通过后生效。
> **生效日期**:2026-08-29 · **版本**:v1.0
