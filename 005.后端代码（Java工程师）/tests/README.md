# 005 Java 后端 — tests/ 目录说明

> 双轨:
>   - Maven 约定的 `src/test/java/**` 与 `src/test/resources/**` 是 JUnit 单测/集成测的家
>   - 仓库根的 `tests/` 是 shell 冒烟 + e2e 脚本 + 报告同步的家
> 两者都不动 `src/main/**` 现有任何业务代码。

## 目录结构

```
005.后端代码（Java工程师）/
├── pom.xml                              Maven 配置(已加 surefire + jacoco 插件)
├── src/main/...                         业务代码(不动)
├── src/test/                            Maven 约定的 test 源根
│   ├── java/com/qingzhang/
│   │   ├── records/RecordsServiceErrorCodesTest.java   账目域 30xx 错误码触发
│   │   ├── reports/ReportsServiceMonthFormatTest.java  报表域 40xx 错误码
│   │   └── admin/security/AdminAuthInterceptorRulesTest.java  Admin 5 规则
│   └── resources/
│       └── application-test.properties   H2 内存库 + Flyway + JWT 测试配置
└── tests/                               新增,根级 tests/
    ├── README.md                        本文件
    ├── smoke/
    │   ├── user-smoke.sh                鉴权/用户域冒烟
    │   └── records-smoke.sh             账目域冒烟
    ├── e2e/                             后续可放 cucumber/jmeter 场景
    └── scripts/
        └── copy-report.mjs              同步报告到 008.项目测试/测试报告/005-java-backend/
```

## 命令(由 pom.xml 插件提供)

```bash
mvn test                                       # 跑 JUnit 单测 + 集成测
mvn test -Dtest=RecordsServiceErrorCodesTest   # 单类
mvn verify                                     # 跑 test + jacoco 报告
mvn -DskipTests=false -Psmoke test             # 跑 JUnit + smoke(若挂到 profile)
./tests/smoke/user-smoke.sh                    # 直接跑冒烟(后端需在跑)
./tests/smoke/records-smoke.sh
npm run test:report:copy                       # 借 package.json 的脚本(可选)
node tests/scripts/copy-report.mjs 005-java-backend
```

## 报告输出

- **Surefire HTML**:`target/surefire-reports/` + 同步到
  `../../008.项目测试（测试工程师）/测试报告/005-java-backend/surefire/`
- **JaCoCo coverage HTML**:`target/site/jacoco/index.html` + 同步到
  `../../008.项目测试（测试工程师）/测试报告/005-java-backend/coverage/`
- **Smoke 日志**:`tests/smoke/*.log` + 同步到
  `../../008.项目测试（测试工程师）/测试报告/005-java-backend/smoke/`

## pom.xml 新增的关键插件

- `maven-surefile-plugin` — JUnit 报告
- `jacoco-maven-plugin` — 覆盖率
- `maven-failsafe-plugin` — 集成测试(`*IT.java` 命名)

阈值起步:
```xml
<jacoco.coverage.minimum>0.60</jacoco.coverage.minimum>  <!-- 起步 60% -->
```

## 当前状态

- 3 个 JUnit 测试类骨架就位,1 个跑通(`invalidType` → 3010)
- 2 个 shell 冒烟脚本骨架就位
- H2 内存库 test profile 配置就位,但视图兼容脚本 `db/migration-h2-compat/` 待补
  (V1~V9 在 H2 上的 ENUM/视图兼容是已知卡点 — 见 Q2 决策)
- surefire + jacoco 插件待补到 pom.xml

## 新增依赖

`pom.xml` 内更新(后续 PR 加):
- `org.springframework.boot:spring-boot-starter-test`(scope test,已有)
- `com.h2database:h2`(scope test,已有)
- `org.assertj:assertj-core`(scope test,新增)
- `org.mockito:mockito-core` / `mockito-junit-jupiter`(scope test,已有随 starter)
- maven 插件:`maven-surefire-plugin` / `jacoco-maven-plugin` / `maven-failsafe-plugin`

## 关键约定

1. **测试账号**:沿用 [不准修改已有账号密码] 规则。
   - `authtest_admin` / `AuthTest@12345`(admin 角色)
   - `authtest_viewer` / `AuthTest@12345`(viewer 角色)
   - `authtest_smoke_$(date +%s)`(冒烟用临时账号,跑完清理)
2. **不动 src/main/** — 所有测试代码独立目录。
3. **V9 物理删除不可逆** — 任何数据库清理脚本必须先 SELECT 备份,经用户确认后才 DELETE。