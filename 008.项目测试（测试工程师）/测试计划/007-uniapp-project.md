# 测试计划 — 007 uniapp-project

**项目**:轻账 uni-app(Vue 3 + Vite + uview-plus + Pinia)
**目标平台**:**3 个独立运行环境**
- H5(Chrome / Safari / 微信内置)
- iOS APP-PLUS(WKWebView 真机)
- mp-weixin(微信小程序基础库 ≥ 2.32.3)
**对接**:Java 后端 `:4001`(`VITE_API_BASE` 默认 `http://localhost:4001`,**H5 dev 端口 = 5181**[项目约束])
**当前覆盖率**:**0**(无单测;只有冒烟验证过三平台手动点一遍)

---

## 1. 技术栈与目录结构

| 项 | 选型 |
|---|---|
| 框架 | uni-app(编译期支持 H5 / APP-PLUS / MP-WEIXIN)+ Vue 3 + Pinia 2.1.7 |
| UI | uview-plus ^3.3.62 |
| 平台原生 | uni_modules `qa-window-bg`(iOS APP-PLUS 用,改 UIWindow.backgroundColor) |
| 调试 | vconsole(H5) |
| Polyfill | `utils/url-polyfill.ts`(微信小程序基础库缺 URLSearchParams 兜底) |

```
uniapp-project/
├── main.js                createSSRApp + Pinia + 平台条件编译
├── App.vue                app-root + ToastHost + 5 tabBar 页 tabbar-page class
├── manifest.json          5+App / mp-weixin / h5 配置(appid wx7cd4eca6face3bd6)
├── pages.json             12 个页面 + tabBar(5 个)
├── pages/
│   ├── login/index        登录/注册
│   ├── index/index        首页(挂载 <QuickAddModal />)
│   ├── transactions/index 流水
│   ├── record/expense     记支出
│   ├── record/income      记收入
│   ├── reports/monthly    月报
│   ├── accounts/index     账户
│   ├── accounts/new       新建账户
│   ├── books/index        账本
│   ├── books/members      账本成员
│   ├── settings/index     我的
│   └── profile/edit       资料编辑
├── components/
│   ├── AppHeader.vue
│   ├── MonthPicker.vue
│   ├── QuickAddModal.vue    ← 953 行,三平台兼容重点,本次新加 iOS 直接渲染分支
│   ├── RecordForm.vue
│   ├── TransactionRow.vue
│   ├── Toast.vue
│   ├── DonutChart.vue
│   ├── ColorSwatch.vue
│   └── charts/              (子目录)
├── stores/
│   ├── auth.ts              JWT(qz_token)+ onAuthInvalid + 3 秒 NAV_GRACE 压制
│   ├── book.ts              账本切换 + reload
│   ├── language.ts          i18n
│   ├── theme.ts             暗/亮主题
│   ├── toast.ts             吐司
│   └── quick-add.ts         全局 modal state(避免 page 容器裁掉)
├── api/                     auth / books / accounts / categories / records / reports / users / version / http.ts
├── utils/                   account-presentation / back / category-presentation / date / export / finance / modal-state / nav-intent / url-polyfill
├── i18n/                    LanguageContext + dict.ts
├── theme/                   global.scss
├── uni_modules/
│   └── qa-window-bg/        app-android / app-ios / web / mp-weixin 5 个 utssdk 分支
└── static/                  tabBar 图标 + assets
```

## 2. 启动方式

```bash
cd "007.跨端APP应用（移动端开发工程师）/uniapp-project"

# H5 dev
npm run dev:h5                      # → http://localhost:5181

# 微信小程序(在 HBuilderX 里)
# 运行 → 运行到小程序模拟器 → 微信开发者工具

# iOS APP-PLUS
# HBuilderX → 发行 → 原生 APP-云打包 / 自定义基座
```

**前置**:Java 后端必须起在 4001。
**重要约束**:H5 dev 端口 **5181**(非默认 5173);后端 CORS 白名单必须含 5181。

## 3. 核心业务模块

| 模块 | 路径 | 关键能力 |
|---|---|---|
| 登录 | `pages/login/index` | username/password → JWT → localStorage(qz_token)→ 跳首页 |
| 首页 | `pages/index/index` | 月份选择 + 卡片概览 + 最近流水 + 分类汇总 + **快速记账按钮** |
| 快速记账 | `components/QuickAddModal.vue`(953 行,Pinia store) | 金额输入键盘、分类网格、账户 chips、备注、提交,**3 平台差异化** |
| 流水 | `pages/transactions/index` | 5 维过滤、tabBar 切回自动 reload |
| 记账 | `pages/record/expense` + `income` | 完整记账页(非弹框) |
| 账户 | `pages/accounts/index` + `new` | CRUD |
| 报表 | `pages/reports/monthly` | 月报 + 图表 |
| 账本 | `pages/books/index` + `members` | 多账本 + 成员 |
| 我的 | `pages/settings/index` + `profile/edit` | 改昵称/改密/主题/语言 |

**3 平台差异点**(必须分别测):
| 关注点 | H5 | iOS APP-PLUS | mp-weixin |
|---|---|---|---|
| QuickAddModal 渲染 | `<Teleport to="body">` | **直接渲染分支**(本会话修复) | 直接挂(无 Teleport 标签) |
| tabBar 控制 | CSS `body.qa-open .uni-tabbar { display:none }` | `uni.hideTabBar()/showTabBar()` | 原生 tabBar 自动让位 |
| Modal 背景 | html/body bg 染 navy | UIWindow bg 改 navy(uni_modules `qa-window-bg`)+ #141E3C | 小程序原生导航栏 |
| 软键盘 | 标准 | iOS WKWebView 软键盘弹起触发 viewport 变化 | input 组件 |
| 滚动容器 | `<scroll-view>` + body bg 关闭弹性 | `<scroll-view>` | `<scroll-view>` |
| vConsole | ✅(dev) | ❌ | ❌ |

## 4. 高风险功能(优先级 P0)

| # | 风险点 | 失败后果 |
|---|---|---|
| H1 | **QuickAddModal 弹框** — Vue 3 `<Teleport>` 在 iOS Safari + WKWebView 编译产物下崩 `i.parentNode null` / `_vei` / `setAttribute null`(本次会话新增 isIOS 直挂分支) | iOS 端完全不弹 |
| H2 | **tabBar 隐藏 / 显示** — 三平台走不同路径 | modal 露出 tabBar |
| H3 | **iOS 顶部安全区**(Dynamic Island / status bar)— H5 走 `theme-color` + `apple-mobile-web-app-status-bar-style`,iOS 走 `qa-window-bg` 原生插件,mp 走原生导航栏 | 顶部露白边 |
| H4 | **滚动到底被 fixed tabBar 盖** — `.tabbar-page.page-root` 用 `position:fixed;bottom:var(--tab-bar-height)` 钉 | 内容被遮 |
| H5 | **登录 1401 踢回** — `runSilent()` 抑制 + `NAV_GRACE_MS=3000` 3 秒被动加载窗口压制 | 刷新页面被踢回登录 |
| H6 | **i18n 缺 key 渲染** — dict.ts 漏一个 key → `[object Object]` | UI 残缺 |
| H7 | **uni_modules 原生插件调试限制** — debug 包不生效,只能真机测 | 上线才发现 UIWindow bg 没改 |
| H8 | **跨平台 API 差异** — `uni.getStorageSync` / `uni.request` / `uni.reLaunch` 在 3 平台语义微差异 |
| H9 | **微信小程序 URLSearchParams 缺失** — `utils/url-polyfill.ts` 兜底 | SSR ReferenceError,页面全空 |
| H10 | **xlsx 导出** — mp 端可能不支持文件写入 → 失败 | 用户拿不到导出 |
| H11 | **暗色主题**(iOS Safari + 系统 dark mode + CSS) | UI 闪烁或对比度差 |

## 6. 分层测试方案

### 6.1 平台抽象单元测试(vitest + happy-dom)
**目标**:抽取并测**纯逻辑**部分(可在 H5 dev / Node 跑)
**覆盖**:
- `utils/finance.ts`(金额格式化)
- `utils/category-presentation.ts`(分类 → icon/color 映射)
- `utils/account-presentation.ts`
- `utils/date.ts`(`formatLocalMonth`、`formatRelativeDayLabel`、`compareRecordDesc`)
- `utils/export.ts`(xlsx 生成的纯数据组装部分)
- `utils/modal-state.ts`(全屏 modal 打开时的 CSS class 切换)
- `utils/nav-intent.ts`(一次性意图跨页传参)
- `stores/quick-add.ts`(Pinia store 状态机)
- `stores/auth.ts`(纯函数 `getLastUsername` 等)

**目标**:utils + stores 纯逻辑部分 ≥ 80% 覆盖

### 6.2 平台抽象组件测试(@vue/test-utils + happy-dom)
**目标**:在 happy-dom 下挂组件、模拟 store、断言渲染
**覆盖**:
- `<MonthPicker>` 月份切换、跨年
- `<TransactionRow>` record 缺字段降级
- `<Toast>` 队列/TTL
- `<ColorSwatch>` 颜色映射
- `<DonutChart>` 数据空/单点/超长序列
- `<AppHeader>` 标题 / 返回按钮 / 主题色

**注意**:`<QuickAddModal>` 包含大量 `<!-- #ifdef H5 || APP-PLUS -->` 平台条件编译代码,需分别在三平台编译产物下测 — 实际不在 happy-dom 单测范围,留给真机冒烟。

### 6.3 集成测试(MSW + @vue/test-utils)
**工具**:MSW(拦截 fetch,可在 happy-dom 下跑)
**覆盖**:
- 路由跳转:`/pages/login/index` → `/pages/index/index` → 打开 QuickAddModal → 提交 → 跳回 → 流水刷新
- 1401 全局处理:`onAuthInvalid` 触发 → `runSilent` 抑制 → `NAV_GRACE` 抑制
- 月份切换 → 流水 + 报表重新加载
- 账本切换 → store 切换 → 列表数据刷新

### 6.4 真机 E2E(三平台分别)

| 平台 | 工具 |
|---|---|
| H5 (Chrome) | Playwright + `http://localhost:5181` |
| H5 (Safari / iOS WKWebView) | 手动 + 截图,真机或 BrowserStack |
| mp-weixin | 微信开发者工具 + miniprogram-automator |
| iOS APP-PLUS | HBuilderX 自定义基座 + 真机调试 |

**用例清单**(优先级):
1. **H5 Chrome** + 注册 → 首页 → 点快速记账 → 弹框 → 选分类 → 输入金额 → 选账户 → 提交 → 跳回看到新记录
2. **iOS 真机** + 同上(本会话修复后必跑 — 验证 `i.parentNode null` 不再出现)
3. **mp-weixin** + 同上,验证 modal 走直接挂分支
5. **H5 iPhone Safari** + 上下滚动 → 最后一行不被 tabBar 盖
6. **H5 iPhone Safari** + 切横屏 → tabbar height 自动重测(`resize` 事件)
7. **H5 iPhone Safari** + 模态打开 → `body.qa-open` 生效 → `.uni-tabbar` 隐藏
8. **iOS 真机** + 模态打开 → UIWindow bg 改 navy(原生插件生效)
9. **H5 Chrome** + 1401 模拟 → `runSilent` 抑制期内不跳 → 退出抑制后正常跳登录
10. **mp-weixin** + URLSearchParams 缺失环境模拟 → polyfill 兜底生效
11. **H5** + i18n 切换中文/英文 → 所有页面 key 全
13. **mp-weixin** + xlsx 导出 → 模拟下载到本地
14. **暗色主题** — 切换系统暗色 → 重新启动 → 主题生效

### 6.5 平台对比测试(差异回归)
每次发布前固定跑:
- 同一笔记账:H5 / iOS / mp 三端各自创建 → 数据一致(同账户余额一致)
- 同一场景的截图对比(同 UI 设计 token 下,三平台视觉无明显差异)

### 6.6 性能 / 流畅度(iOS 真机)
- QuickAddModal 打开动画无卡顿
- 流水页 1000 条滚动 fps
- 报表页图表渲染 < 1s

### 6.7 安全 / 兼容
- JWT 注入:token 过期 / 篡改 / 短超时
- CORS:5181 跨域请求 + 自定义 header
- iOS 版本覆盖:iOS 15 / 16 / 17 / 18(WKWebView 版本差异)
- mp 基础库覆盖:2.32.3 / 3.0 / 最新

## 7. 测试环境与数据

- 后端:Java `:4001` + MySQL 3307 + Flyway V1~V9 全迁移
- H5 dev:`npm run dev:h5` → http://localhost:5181
- mp:`HBuilderX` + `微信开发者工具` + appid `wx7cd4eca6face3bd6`
- iOS:`HBuilderX` 自定义基座 + iPhone 真机(iOS 17/18)
- 测试账号:`uniaptest1` / `Test@12345`(不可复用 `dbtest1`)

**真机矩阵**(成本受限,建议覆盖):
- H5:Chrome desktop + iOS Safari 17 + Android Chrome
- iOS APP-PLUS:iPhone 12(iOS 16)+ iPhone 15(iOS 17/18)
- mp:微信开发者工具 + 真机 1 部

## 8. 进入/退出准则

**进入下一阶段**:
- [ ] HBuilderX 安装,自定义基座就绪
- [ ] 真机 / 模拟器矩阵确认
- [ ] `qa-window-bg` 在 debug 包不生效的限制有 workaround(手动编译发布版测一次)

**测试通过**:
- [ ] 单测 + 组件测试覆盖率 ≥ 70%(utils 100%)
- [ ] 14 个真机 E2E 用例全绿
- [ ] **H1 修复回归**:iOS 真机 QuickAddModal 弹框无 `parentNode` / `_vei` / `setAttribute null` 报错
- [ ] 三平台数据一致性:同笔记账余额一致
- [ ] tabBar 隐藏 / 顶部安全区 / 滚动遮挡 三类 UI 问题无回归
- [ ] i18n 全文 key 无缺漏

---

## 9. 待澄清/需用户决策

| 问题 | 选项 |
|---|---|
| 1. iOS 真机矩阵要求覆盖多少机型 / 系统版本? | A. 2 机型(iOS 16/17)B. 3 机型(含 iOS 18)C. 全覆盖 |
| 2. 是否引入 miniprogram-automator 做 mp E2E 自动化? | A. 引入(推荐)B. 手动 |
| 3. mp SVG 走 data URI(项目记忆约束)— 测试时是只测渲染,还是要测导出文件大小/体积? | A. 只测渲染 B. 测体积(< 4KB 上限)|
| 4. CI 是否搭 HBuilderX + 真机调度? | A. 不搭(本地真机跑)B. 搭(用云打包 + 蒲公英) |
| 5. 三平台差异测试是否每个版本发布都跑? | A. 是 B. 仅大版本 |

---

**生成时间**:2026-09-04
**生成方**:Claude (由 008.项目测试 目录工作流触发)