# QingZhang · uniapp 版「轻账」

uni-app + Vue3 + Pinia + uview-plus 跨端记账应用,同时输出 **H5** 与**微信小程序**两套产物。配套 Flutter 版 `../flutter-project/`,共享 `005.后端代码(Java工程师)/` 后端。

## Prerequisites

- Node.js ≥ 22
- Java 后端已起在 **4001** 端口(`005.后端代码(Java工程师)/`),MySQL `qingzhang` 数据库可用
- H5 调试:Chrome / Safari / 手机浏览器(扫码)
- 小程序调试:[微信开发者工具](https://developers.weixin.qq.com/miniprogram/dev/devtools/download.html)
- 小程序 AppID:`wx7cd4eca6face3bd6`(`manifest.json`)

## Quick Start

```bash
# 1. 安装依赖
npm install

# 2. 启动后端(项目后端独立仓库,默认 http://localhost:4001)

# 3. 启动 H5 dev server
npm run dev:h5          # http://localhost:5181 (手机扫码访问)

# 3'. 或启动微信小程序 dev
npm run dev:mp-weixin   # 产物在 dist/dev/mp-weixin,导入微信开发者工具

# 4. 单测
npm run test            # 全部 vitest
npm run test:unit       # 只跑 tests/unit
npm run test:stores     # 只跑 Pinia stores
```

> H5 dev 端口 **5181** 固定(`vite.config.js`),跟后端 CORS 白名单对齐;**非默认 5173**。手机扫码访问需 `npm run dev:h5` 自动开启 `--host`。

| command                   | purpose                                          |
|---------------------------|--------------------------------------------------|
| `npm run dev:h5`          | H5 dev server (Vite, port **5181**)              |
| `npm run dev:mp-weixin`   | 微信小程序 dev(产物 → 微信开发者工具导入)        |
| `npm run build:h5`        | H5 生产构建                                      |
| `npm run build:mp-weixin` | 微信小程序生产构建                               |
| `npm run test`            | 全部 vitest 单测                                 |
| `npm run test:unit`       | 只跑 `tests/unit/**`                             |
| `npm run test:stores`     | 只跑 Pinia stores                                |
| `npm run test:e2e`        | Playwright E2E(慢,可选)                         |
| `npm run test:coverage`   | v8 coverage → `tests/coverage/`                  |

## 环境变量

| name            | default                  | 说明                                                |
|-----------------|--------------------------|-----------------------------------------------------|
| `VITE_API_BASE` | `http://${LAN_IP}:4001`  | 后端基础地址;解析优先级 `本项目 .env.local` > 仓库根 `.env` 的 `LAN_IP` |

### 解析规则

- `vite.config.js` 的 `resolveApiBase()`:**优先读本项目 `.env.local` / `.env.[mode]`**,没有则 fallback 到仓库根 `.env` 的 `LAN_IP` + `:4001`。
- 改一处即可:全局 LAN IP 在仓库根 `../.env`,写 `LAN_IP=192.168.1.x`,所有 uniapp / Flutter / 前端项目跟随。
- 临时指向本地后端:`uniapp-project/.env.local` 写 `VITE_API_BASE=http://localhost:4001` 覆盖。

## 项目结构

```
uniapp-project/
├── App.vue                 # 入口组件:启动 hooks + tabBar 自适应
├── main.js                 # createApp() + Pinia + polyfill 注入
├── pages.json              # 路由 + tabBar 配置(12 页)
├── manifest.json           # 应用元信息 + 微信小程序 AppID
├── pages/                  # 12 个页面
│   ├── login/              # /login
│   ├── index/              # 首页
│   ├── transactions/       # 流水
│   ├── record/{expense,income}/
│   ├── reports/monthly/    # 月度报表
│   ├── accounts/{index,new}/
│   ├── books/{index,members}/
│   ├── settings/           # 我的
│   └── profile/edit/
├── components/             # 业务组件(Toast/AppHeader/MonthPicker 等)
├── stores/                 # Pinia:auth/book/theme/language/quick-add
├── api/                    # 后端 HTTP 客户端(records/books/auth/...)
├── utils/                  # 工具(date/export/category-presentation/...)
├── i18n/                   # 多语言资源
├── theme/                  # global.scss + 设计 token
├── uni_modules/            # uview-plus + 自定义 uni_modules
├── static/                 # tabbar 图标等静态资源
├── tests/                  # vitest 单测 + Playwright E2E
├── vite.config.js          # Vite + @dcloudio/vite-plugin-uni
└── vitest.config.ts        # happy-dom 单测环境
```

## 与 Flutter 版本对应

| uniapp 路径                          | Flutter 对应                                                  |
|--------------------------------------|---------------------------------------------------------------|
| `pages/login/index.vue`              | `lib/features/auth/login_screen.dart`                         |
| `pages/index/index.vue`              | `lib/features/home/home_screen.dart`                          |
| `pages/transactions/index.vue`       | `lib/features/transactions/transactions_screen.dart`          |
| `pages/reports/monthly.vue`          | `lib/features/reports/reports_screen.dart`                    |
| `pages/accounts/{index,new}.vue`     | `lib/features/accounts/{accounts,account_new}_screen.dart`    |
| `pages/books/{index,members}.vue`    | `lib/features/books/{books,book_members}_screen.dart`         |
| `pages/settings/index.vue`           | `lib/features/settings/settings_screen.dart`                  |
| `pages/profile/edit.vue`             | `lib/features/auth/profile_edit_screen.dart`                  |
| `components/AppHeader.vue`           | `lib/features/shared/app_header.dart`                         |
| `components/Toast.vue`               | `lib/features/shared/toast.dart`                              |
| `stores/auth.ts`                     | `lib/features/shared/auth_controller.dart`                    |
| `stores/book.ts`                     | `lib/features/shared/book_controller.dart`                    |
| `stores/theme.ts`                    | `lib/features/shared/theme_controller.dart`                   |
| `stores/language.ts`                 | `lib/core/i18n/locale_provider.dart`                          |

## 关键技术点

- **小程序 SVG 走 data URI image**:Vue3 mp 里不要用 canvas,SVG 嵌 `<image src="data:image/svg+xml...">` 才是稳的。
- **VConsole 调试浮窗**(`main.js`):H5 dev/prod 都启用,4 个面板(Network / Console / Storage / Element);生产打包前手动注释。
- **URL polyfill**(`utils/url-polyfill.ts`):微信小程序基础库缺 URLSearchParams,Vue3 SSR 模式用到会 ReferenceError;polyfill 内部 typeof 检测会跳过 H5/现代 mp。
- **tabBar 高度自适应**(`App.vue` `measureTabBar`):uniapp H5 不会自动写 `--tab-bar-height`,5 个 tabBar 页用 `calc(100vh - var(...))` 计算剩余视口,本组件主动量 position:fixed 元素 + 重试 10 次 100ms。
- **easycom 自动注册**(`pages.json`):`components/foo/foo.vue` 路径解析,无需手动 import。
- **H5 端口固定 5181**:与 005 CorsConfig 5181 白名单对齐,见 [[uniapp-h5-dev-port-5181]]。

## 已知简化

- **不接入 sentry / datadog**:`console.error` / `console.warn` 直接打到控制台,7 处全部是有意诊断(网络错误 / 边界兜底)。
- **不做端到端 mock**:`tests/e2e` 仅 Playwright smoke,业务 E2E 由 QA 维护。
- **不输出支付宝 / 抖音 / 百度小程序**:`manifest.json` 配置项保留但不主动构建,按需 `dev:mp-xxx`。