# 测试计划 — 005 Java 后端

**项目**:轻账 Spring Boot 后端(完全替代原 Node :4000)
**端口**:4001
**技术栈**:Spring Boot 3.5.0 + JDK 21 + Maven + MyBatis-Plus 3.5.9 + MySQL 9.7.2 + Flyway 10.20.1 + JJWT 0.12.6 + BCrypt(Spring Security crypto)+ dynamic-datasource 4.5.0(多数据源,admin 库独立)
**当前覆盖率**:**0**(`src/test/` 不存在;只有 `pom.xml` 的 `spring-boot-starter-test` + H2)

---

## 1. 技术栈与目录结构

```
com.qingzhang
├── QingZhangApplication.java
├── auth/                       JwtUtil + JwtAuthFilter + AuthController/Service
│                               UserAuthInterceptor + dto/Credentials / UserDTO / AuthResponse
├── users/                      UsersController/Service + entity/User + mapper + dto(改昵称/改密码)
├── books/                      BooksController/Service + entity + mapper + dto
│   (含 AddMemberRequest / BookResponse / CreateBookRequest /
│    MemberResponse / UpdateBookRequest / UpdateMemberRoleRequest)
├── accounts/                   AccountsController/Service + entity/Account + AccountBalance(view)
│                               + AccountMapper + dto(AccountResponse / Create / Update)
├── categories/                 CategoriesController/Service + entity/Category + mapper + dto
├── records/                    RecordsController/Service + entity/Record + RecordMapper + dto
│                               5 维过滤(month / from / to / type / categoryId / accountId / bookId)
├── reports/                    ReportsController/Service + mapper + 月报/年报 DTO
├── admin/                      ← 独立子系统(见 006 计划)
│   ├── auth/   books/   categories/   records/   users/   businessusers/
│   ├── audit/  dashboard/   bootstrap/   dto/   entity/   mapper/   security/
├── common/                     ApiResponse / BizException / ErrorCode(1xxx/10xx/30xx/40xx/9xxx)
├── exception/                  GlobalExceptionHandler
├── controller/                 RootController(/)+ VersionController(/api/version)
└── config/                     AdminInterceptorConfig / AuthFilterConfig / CorsConfig /
                                FlywayConfig / MybatisPlusConfig / UserInterceptorConfig
```

**数据库迁移**(Flyway V1~V9,不可改 V1):
- V1 baseline(10 表 + 2 视图)
- V2 预设分类(14 条)
- V3 category.name 扩列
- V4 users.salt 可空
- **V5** admin RBAC + 5 表 + 3 角色 + 17 权限
- V6 admin_users 拆分
- V7 drop admin tables
- **V8** users.token_version(后端踢人用)
- **V9** 物理清理 `records` 软删除遗留(`DELETE FROM records WHERE deleted_at IS NOT NULL` — **不可逆**)

## 2. 启动方式

```bash
# 前置
docker compose up -d                                # MySQL 9.7.2,端口 3307
mvn -DskipTests package
export JWT_SECRET="<32+ bytes random>"
java -Dspring.profiles.active=dev \
     -cp "target/classes:$(cat /tmp/qz-cp.txt)" \
     com.qingzhang.QingZhangApplication

# 或
mvn spring-boot:run
# 健康检查
curl http://localhost:4001/api/version
```

**Admin Bootstrap**(可选):
```bash
export ADMIN_BOOTSTRAP_USERNAME=superadmin
export ADMIN_BOOTSTRAP_PASSWORD='StrongP@ssw0rd!'
./start-backend   # 首次启动会创建 super_admin 账号
```

**测试启动**:
```bash
mvn test                         # 默认 H2 内存库
mvn test -Dspring.profiles=it    # 集成测试(假想 profile)
```

## 3. 核心业务模块

| 域 | 路径 | 错误码区间 | 关键能力 |
|---|---|---|---|
| 认证 | `auth/` | 10xx | register/login/me/logout、BCrypt、JWT 签发/校验、`token_version` 踢人(V8) |
| 用户 | `users/` | 10xx | 改昵称、**改密码**、`/me` 个人资料 |
| 账本 | `books/` | 20xx | 多账本 CRUD、成员增删、改角色、跨账本权限校验 |
| 账户 | `accounts/` | — | CRUD、余额走视图 `v_account_balance` |
| 分类 | `categories/` | — | 预设 + 自定义,只读列表 |
| 账目 | `records/` | **30xx**(3001~3017) | expense/income/transfer 三型、5 维过滤、转账联动视图 |
| 报表 | `reports/` | **40xx**(4001/4002) | 月报/年报聚合 SQL、补缺失日/月、跨年月份 |
| Admin | `admin/` | **14xx**(1411/1403/1410/1413/1412/1420/1490/1499) | RBAC、审计日志、`token_version` 校验 |
| 通用 | `common/` | 1xxx/9xxx | ApiResponse 信封、BizException、ErrorCode |

**关键视图**:
- `v_account_balance` — 账户实时余额
- `v_monthly_summary` — 月度收支汇总

## 4. 高风险功能(优先级 P0)

| # | 风险点 | 失败后果 |
|---|---|---|
| H1 | **JWT 时效 + token_version**(V8) | 旧 token 仍可用 → 用户被禁用后仍能操作 |
| H2 | **RecordsService.transfer 联动 + 视图依赖** | 转账账户余额算错(account_id 减、to_account_id 加) |
| H3 | **跨账本权限**(`booksService.mustAccessibleBook`) | A 账本成员能读写 B 账本 → 数据越权 |
| H4 | **报表 SQL 聚合** + 补缺失日/月 | 月报少一天、年报少一月、前端图表断点 |
| H5 | **转账校验**(同账户 / 缺 toAccount / 类型不匹配 3011~3017) | 转账失败但账户已改 |
| H6 | **CORS 配置**(5173 React 主、5174 Admin、5181 uniapp H5 — 依[uniapp H5 dev 端口是 5181]规则) | 跨域失败前端拿不到数据 |
| H7 | **AdminAuthInterceptor** 链(JWT 24h iat + token_version + admin 角色 + 权限码) | 权限提升 / 失效 |
| H8 | **V9 物理删除** | 不可逆操作执行前/中误删 |
| H9 | **Flyway 迁移一致性** | 漏迁移或破坏 V1 schema |
| H10 | **BigDecimal 序列化精度** | 报表金额精度丢失 |

## 5. 分层测试方案

### 5.1 单元测试(JUnit 5 + Mockito)
**目标覆盖率**:Service 层 ≥ 80%,Mapper 层用 SQL 直接验证
**重点**:
- `RecordsService` 全部 8 个错误码触发路径(3010~3017)
- `AuthService`:BCrypt 校验、JWT 签发/校验、`token_version` 校验
- `ReportsService.monthly/yearly`:跨年月份、缺失日补 0、空数据态
- `BooksService.mustAccessibleBook`:owner / member / 陌生人 / archived 4 状态
- `AdminAuthInterceptor` 5 条规则任一不通过 → 401/403

### 5.2 持久层测试(@MybatisPlusTest + H2 / Testcontainers MySQL)
**工具**:`@MybatisPlusTest` + H2(or Testcontainers MySQL 镜像跑真 schema)
**覆盖**:
- Flyway V1~V9 在 H2/MySQL 上迁移成功(schema 兼容!)
- `v_account_balance` 视图在 H2 上重写为等价的派生表(因 H2 不支持视图)
- `v_monthly_summary` 同上
- 视图聚合结果与手算一致

### 5.3 集成测试(@SpringBootTest + MockMvc)
**覆盖**:
- 全部 REST 端点(Controller 走通 Service 走通 Mapper 走通 DB)
- 7 个 filter 组合(record:month/from/to/categoryId/type/accountId/bookId)
- 401 → 1401 信封一致
- 403 → 1403 信封一致
- 403 admin → 1411 / 1403 信封一致
- 异常路径:Validation 失败返 1000、SQL 异常返 9999
- **JWT 注入**:过期 token / 篡改 token / token_version 不匹配

### 5.4 契约测试(Spring Cloud Contract 或自写 consumer-driven)
**目的**:保证 Java 后端 envelope `{code,message,data}` 与 React 前端 `lib/api.ts` `ApiEnvelope<T>` 严格对齐
**重点 DTO**:`AuthResponse` / `AccountResponse` / `RecordResponse` / `MonthlyReportResponse` / `YearlyReportResponse`
**反例**:`Record.amount` 是 BigDecimal 序列化成 number 还是 string?

### 5.5 端到端 / 冒烟测试
- 复用根目录 `admin-smoke.sh`(覆盖 admin 10 场景)
- 新增 `user-smoke.sh`(类似风格,覆盖 register/login/CRUD/transfer/report 6 路径)
- 跑前:**清库 + Flyway migrate + seed preset categories**(`V2__seed_preset_categories.sql`)

### 5.6 安全/权限测试
- 越权访问:A 的 token 访问 B 的 uuid → 403
- JWT 重放:旧 token_version 不匹配 → 401
- 跨账本:member 改 owner-only 字段 → 403
- CORS:5173 / 5174 / 5181 跨域请求带自定义 header → 通过;恶意 origin 拒绝

### 5.7 性能 / 负载(JMeter / k6)
- 100 并发 GET /api/records(月份过滤)
- 50 并发 POST /api/records(高频记账)
- 报表聚合 < 500ms p99

### 5.8 数据迁移测试
- Flyway 任意 V(N-1)→V(N) 升级路径
- V9 物理清理前后行数 diff(预演备份再清)
- V8 token_version 不影响 JWT 兼容性

### 5.9 兼容性 / 健壮性
- BigDecimal 精度:0.1 + 0.2 = 0.3
- 长字段:username 21 字 / book name 51 字 / category name 51 字
- SQL 注入:filter 字段全注入探针
- 并发:同一 record 同时 PATCH / DELETE → 一个成功一个 404
- 时区:LocalDate vs Instant、跨日记录归属

## 6. 测试环境与数据

| 环境 | 数据库 | JWT_SECRET |
|---|---|---|
| 本地 dev | MySQL 3307 + Flyway | dev 默认 |
| 单元/集成测试 | **H2 内存库 + Flyway + 视图派生表** | 测试固定 |
| E2E/冒烟 | MySQL 3307 独立 schema `qingzhang_test` | 测试固定 |
| CI(规划) | Testcontainers MySQL | 测试固定 |

**测试账号策略**(参考 [不准修改已有账号密码] 规则):
- 不可用 `dbtest1` 等已有真实账号
- 测试用 `authtest1` / `AuthTest@12345`(待 QA 创建)

## 7. 关键测试场景清单

### 7.1 Records 域(全 P0,30xx)
| 场景 | 输入 | 期望 |
|---|---|---|
| transfer 同账户 | accountId == toAccountId | 3014 SAME_ACCOUNT_TRANSFER |
| transfer 缺 toAccountId | type=transfer, toAccountId=null | 3013 TO_ACCOUNT_REQUIRED |
| expense 缺 categoryId | type=expense, categoryId=null | 3011 CATEGORY_REQUIRED |
| categoryId 类型不匹配 | type=expense + income 类 | 3012 CATEGORY_TYPE_MISMATCH |
| type 非法 | type="xxx" | 3010 INVALID_TYPE |
| 账户不在账本 | accountId 在其他 book | 3017 ACCOUNT_NOT_IN_BOOK |
| recordDate 格式错 | "2026/09/04" | 3015 INVALID_RECORD_DATE |
| 软删/PATCH 不存在 | PATCH 已硬删的 | 3001 RECORD_NOT_FOUND |

### 7.2 报表域(40xx)
| 场景 | 输入 | 期望 |
|---|---|---|
| month 格式错 | "2026-9" | 4001 BAD_MONTH |
| year 越界 | year=1899 或 10000 | 4002 BAD_YEAR |
| 跨年 | month=2026-01 | 上月 = 2025-12 |
| 缺失日补 0 | month 全空 | dailyData 31 天全部 0 |
| bookId 不可访问 | 其他账本 uuid | 校验失败 |

### 7.3 Auth 域(10xx)
- 改密码后旧 token → 401(V8 token_version)
- 重置密码后 admin token → 401
- 同 username 注册两次 → 1001 唯一冲突
- 禁用账号 login → 1012 USER_DISABLED

## 8. 进入/退出准则

**进入下一阶段**:
- [ ] Flyway 在 H2 上全部迁移成功
- [ ] `v_account_balance` / `v_monthly_summary` H2 兼容方案落地

**测试通过**:
- [ ] Service 单测覆盖率 ≥ 80%
- [ ] Controller 集成测试 100% 覆盖(60+ endpoints)
- [ ] Records 域 3010~3017 全部错误码 100% 触发验证
- [ ] AdminAuthInterceptor 5 规则每条都有反向用例
- [ ] smoke.sh 全绿
- [ ] 性能:报表聚合 p99 < 500ms

---

## 9. 待澄清/需用户决策

| 问题 | 选项 |
|---|---|
| 1. 持久层测试用 H2 还是 Testcontainers MySQL? | A. H2(快,需重写视图)B. Testcontainers MySQL(慢,完全真实) |
| 2. admin 业务的测试计划是否拆为独立文件? | A. 拆为 005-admin.md B. 合并在此文件 |
| 3. 是否引入 Spring Cloud Contract? | A. 引入 B. 自写 envelope 断言 |
| 4. CI 是否部署? | A. GitHub Actions + MySQL service container B. 本地跑 |

---

**生成时间**:2026-09-04
**生成方**:Claude (由 008.项目测试 目录工作流触发)