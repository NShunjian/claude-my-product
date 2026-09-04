# 轻账项目测试计划总览

> 跨 4 个项目的端到端测试策略 + 各项目独立测试计划索引
> 生成时间:2026-09-04

## 0. 项目地图

```
轻账(QingZhang)
├── 003.前端代码(前端工程师)/frontend-react-java   React + Vite SPA         端口 5173
├── 005.后端代码(Java工程师)                        Spring Boot REST         端口 4001
├── 006.后台管理系统(运营专员)                       React Admin SPA          端口 5174
└── 007.跨端APP应用(移动端开发工程师)/uniapp-project uni-app (H5/iOS/mp)    H5 端口 5181
```

**共享后端契约**:Java `:4001` 用统一 `ApiResponse<T> = { code:0, message, data? }` 信封;前端按 envelope 解析、code !== 0 抛 `ApiError`。

---

## 1. 各项目独立计划

| 项目 | 计划文件 | 当前覆盖率 |
|---|---|---|
| 003 frontend-react-java | [003-frontend-react-java.md](003-frontend-react-java.md) | 3 个单测文件 / 0 组件测 / 0 E2E |
| 005 Java 后端 | [005-java-backend.md](005-java-backend.md) | **0** — `src/test/` 不存在 |
| 006 Admin 后台 | [006-admin-frontend.md](006-admin-frontend.md) | **0** — vitest 已配但无测试文件 |
| 007 uniapp-project | [007-uniapp-project.md](007-uniapp-project.md) | **0** — 无单测;手动三平台冒烟 |

---

## 2. 跨项目测试分层金字塔

```
                         ╱╲
                         ║║  E2E(Playwright + 真机)
                        ╱──╲
                       ╱    ╲  契约测试(envelope 对齐)
                      ╱──────╲
                     ╱        ╲  集成(MSW / SpringBoot)
                    ╱──────────╲
                   ╱            ╲  组件(RTL / @vue/test-utils)
                  ╱──────────────╲
                 ╱                ╲  单元(vitest / JUnit5)
                ╱──────────────────╲
```

**分工原则**:
- **单元测试** — 4 个项目各自负责,**禁止**跨项目代码
- **契约测试** — 005 后端与 003/006/007 前端**双向对齐**(共享 envelope shape)
- **集成测试** — 005 用 `@SpringBootTest`;前端用 MSW 模拟 005
- **E2E** — 整链路,起 005 真后端 + 各前端 dev server

---

## 3. 共享风险与跨项目测试策略

### R1. **JWT + token_version 踢人**(005 + 003 + 006 + 007 全端)
- 005 启动 → 007/003/006 拉登录拿 token
- 005 后台重置该用户密码 → **全端下次请求应被踢回登录**
- 测试矩阵:4 个前端各跑一次「重置密码后旧 token 操作应 1401」

### R2. **ApiResponse envelope 契约**
- 005 出 `@JsonInclude(NON_NULL)` 信封,前端 `lib/api.ts` + `api/client.ts` + `api/http.ts` 三处解析逻辑
- 测试:5xx 错误码、message 含特殊字符、data 为 null、BigDecimal 序列化

### R3. **CORS 三前端跨域**
- 005 `CorsConfig` 需白名单 5173(003)+ 5174(006)+ 5181(007 H5 dev)
- 测试:每个前端 dev server 真实跨域请求,验自定义 header + 预检(OPTIONS)

### R4. **跨端数据一致性**(005 ↔ 003 ↔ 007)
- 同一用户登录 003(浏览器)+ 007(H5/iOS/mp 任一),创建账户 / 记账 → 双方余额视图实时同步
- 关键验证:005 `v_account_balance` 视图实时性,007 modal 提交后 003 页面刷新看到

### R5. **三平台 UI 一致性**(007 H5/iOS/mp)
- 同笔记账在 3 平台下分别走完流程,最终 `record` 数据完全一致 + UI 视觉差异 < 设计 token 阈值
- 007 §6.4 已列具体用例

### R6. **Admin 操作联动**(006 → 005)
- 006 后台禁用业务用户 → 007/003 该用户登录 → 失败 1012 USER_DISABLED
- 006 重置密码 → 007/003 旧 token 失效(V8)
- 006 启停预设分类 → 007/003 用户列表里同步

---

## 4. 共享测试约定

### 4.1 测试账号管理(参考 [不准修改已有账号密码])
- 绝不复用 `dbtest1` / `admin/admin123` 等已有真实账号
- 各端测试账号独立:
  - 003: `reacttest1` / `ReactTest@12345`
  - 005 单元:用 `authtest_admin` / `AuthTest@12345` + `authtest_viewer` / `AuthTest@12345`
  - 006: `admintest_admin` / `AdminTest@12345` + `admintest_viewer` / `AdminTest@12345`
  - 007: `uniaptest1` / `UniappTest@12345`
- 密码统一格式:`<App>Test@12345`,强度 ≥ 8 位 + 大小写 + 数字 + 符号

### 4.2 后端测试模式
| 场景 | 数据库 | JWT_SECRET |
|---|---|---|
| 单元 | H2 内存 + Flyway | 测试固定 |
| 集成 | H2 内存 + Flyway + 视图派生表 | 测试固定 |
| 端到端 | MySQL 3307 + 独立 schema `qingzhang_test` | 测试固定 |

### 4.3 端口与 CORS 共识
| 项目 | 端口 | CORS 需允许 |
|---|---|---|
| 003 React | 5173 | ✅ |
| 005 后端 | 4001 | (server) |
| 006 Admin | 5174 | ✅ |
| 007 uniapp H5 | **5181**(非默认) | ✅ |

### 4.4 测试数据隔离
- 007 H5 dev 端口 = 5181 必须写入 005 `CorsConfig` 白名单(参考 [uniapp H5 dev 端口是 5181])
- 005 后端跨域白名单 4 个源:`http://localhost:5173` / `http://localhost:5174` / `http://localhost:5181` / `http://localhost:8080`

---

## 5. 测试阶段路线图

```
阶段 1:基础设施    → 5 个项目都跑通 "本地一键启动 + 冒烟"
阶段 2:单元/组件   → 4 个项目都加 vitest/junit,覆盖率 ≥ 70%
阶段 3:契约        → 005 ↔ 003/006/007 envelope 锁版
阶段 4:集成        → MSW + @SpringBootTest 跨层覆盖
阶段 5:E2E         → Playwright 三端全链路 + uniapp 三平台真机
阶段 6:回归        → 跨项目风险点(R1~R6)专门矩阵
阶段 7:性能        → 报表聚合 p99 < 500ms + 三平台 fps
阶段 8:CJ          → CI pipeline(每项目独立 + 跨项目合约)
```

---

## 6. 当前阻塞与待澄清(汇总)

| # | 问题 | 默认建议 | 决策方 |
|---|---|---|---|
| Q1 | E2E 框架 Playwright 是否引入(新依赖) | 引入 | 用户 |
| Q2 | 005 后端持久层测试用 H2 还是 Testcontainers MySQL | H2 + 视图派生表 | 用户 |
| Q3 | 是否搭 GitHub Actions CI | 阶段 8 起 | 用户 |
| Q4 | iOS 真机矩阵覆盖多少机型 | iPhone 12(iOS 16)+ iPhone 15(iOS 17/18) | 用户 |
| Q5 | mp E2E 用 miniprogram-automator 还是手动 | miniprogram-automator | 用户 |
| Q6 | 视觉回归是否启用 | 暂不启用,仅 a11y | 用户 |
| Q7 | 测试账号密码是否就用 §4.1 的默认 | 是 | 用户 |

---

## 7. 测试通过的总准入

任何版本允许发布需满足:
- [ ] 4 个项目各自的 §5~§7 通过项全部勾选
- [ ] 跨项目 R1~R6 风险矩阵全部覆盖
- [ ] CORS 4 源 + JWT envelope + 三前端统一拦截器 一致
- [ ] 无回归:本次会话修复的 iOS QuickAddModal Teleport 崩溃,在 iOS 真机 E2E 中无报错

---

## 8. 相关项目记忆(测试相关)

- [不准修改已有账号密码](../../) — 任何 reset / SQL UPDATE password_hash / Flyway 写死密码,都要先问用户
- [uniapp H5 dev 端口是 5181](../../) — 用户指定,非默认 5173;CORS 白名单必须含 5181
- [提交需要确认](../../) — 测试计划提交也走 git,需列改动清单
- [uniapp mp SVG 走 data URI image](../../) — 视觉测试时 SVG 应嵌 data URI,不要用 canvas

---

**生成时间**:2026-09-04
**生成方**:Claude(由 008.项目测试 目录工作流触发)
**关联文档**:CLAUDE.md(`000.文档纪要`)、各项目 README
**下一步**:用户审阅 → 决策 Q1~Q7 → 进入阶段 1 基础设施启动