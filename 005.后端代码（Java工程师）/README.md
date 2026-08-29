# 轻账 — Java 后端 (V1)

为「轻账」提供 REST API。技术栈:**Spring Boot 3.5 + JDK 26 + Maven + MyBatis-Plus + MySQL 9.7.2 + Flyway + JJWT + BCrypt**。

## 当前状态(V1 已完成)

Java 后端**完全替代**了之前的 Node 后端(原 :4000),前端 `frontend-react-java` 直连 :4001。

| 模块 | 路径 | 说明 |
| --- | --- | --- |
| 版本 | `GET /api/version` | 服务自检 |
| 认证 | `POST /api/auth/register`、`POST /api/auth/login`、`GET /api/auth/me` | BCrypt + JWT |
| 用户 | `GET /api/users/me`、`PATCH /api/users/me`、`POST /api/users/me/password` | 自己资料维护 |
| 账户 | `GET/POST/PATCH/DELETE /api/accounts[/{uuid}]` | 实时余额走视图 |
| 分类 | `GET /api/categories[?type=expense\|income]` | 预设 + 自定义只读 |
| 账目 | `GET/POST/PATCH/DELETE /api/records[/{uuid}]` | CRUD + 转账联动 + 5 个 filter |
| 报表 | `GET /api/reports/monthly?month=YYYY-MM`、`GET /api/reports/yearly?year=YYYY` | 月报 + 年报 |

错误码区间见 `com.qingzhang.common.ErrorCode` 与各 Service 内常量(`1xxx` 通用/`10xx` 用户/`30xx` 账目/`40xx` 报表/`9xxx` 系统)。

## 运行

依赖:**JDK 26**、**MySQL 9.7.2**、**Maven 3.9+**。

```sh
# 1. 启动 MySQL(docker compose,端口 3307 避主机冲突)
docker compose up -d

# 2. 编译 + 启动
cd "005.后端代码（Java工程师）"
mvn -DskipTests package
JWT_SECRET="shared-with-node-side-must-be-at-least-32-bytes-please" \
  java -Dspring.profiles.active=dev \
       -cp "target/classes:$(cat /tmp/qz-cp.txt)" \
       com.qingzhang.QingZhangApplication
# 或: mvn spring-boot:run(JDK 26 + Spring 6.2 ASM 需 ≥ Maven Compiler 3.14)
```

健康检查:

```sh
curl http://localhost:4001/api/version
# {"code":0,"message":"ok","data":{"version":"0.0.1-SNAPSHOT","name":"qingzhang-java-backend"}}
```

## 数据库

- 端口 `3307`(容器内 `3306`);账号 `qingzhang` / `qingzhang123`
- Flyway 自动迁移 `db/migration/V1__baseline.sql`(10 表 + 2 视图)、`V2__seed_preset_categories.sql`(14 预设分类)
- 关键视图:
  - `v_account_balance` — 账户实时余额(联动转账/收入/支出,忽略软删)
  - `v_monthly_summary` — 按用户/账本/月份的收支汇总

## JWT 密钥同步

`jwt.secret` 从环境变量 `JWT_SECRET` 注入(默认占位串,启动时强制 ≥ 32 字节)。与 Node 端共用密钥后,两边的 token 可互相解析。生产部署务必设置:

```sh
export JWT_SECRET="<32+ bytes random>"
```

## 模块分层

```
com.qingzhang
├── auth/      # JwtUtil + JwtAuthFilter + AuthController/Service(register/login/me)
├── users/     # UsersController/Service(改昵称、改密码)
├── books/     # 账本实体 + 注册时自动建默认账本
├── accounts/  # CRUD + v_account_balance 视图
├── categories/# 只读列表(预设 + 自定义)
├── records/   # CRUD + 转账 + 5 个 filter,联动 v_account_balance
├── reports/   # 月报 + 年报,SQL 聚合
├── common/    # ApiResponse / BizException / ErrorCode
└── exception/ # GlobalExceptionHandler
```

## 测试账号

- 用户 `dbtest1` / `NewPass@67890`(P3 改密)
- 预设账户:微信钱包(初始 500,含 1 笔 income 3000、1 笔 expense 88、1 笔 transfer out 100)