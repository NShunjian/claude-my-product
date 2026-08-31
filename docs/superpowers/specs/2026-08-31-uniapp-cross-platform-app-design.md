# uniapp 跨端 APP 设计

**日期:** 2026-08-31
**状态:** 待审
**作者:** Claude

## 1. 目标

把 `003.前端代码（前端工程师）/frontend-react-java` 这个 React Web 应用,
完整克隆成可在 iOS / Android / 微信小程序三端运行的 uniapp 应用。

**硬性要求(来自用户):**
1. 兼容 iOS
2. 兼容 Android
3. 兼容微信小程序
4. 三端与浏览器版本 **完全一致**:页面结构、字段、文案、行为(增删改查/权限/校验/提示) 1:1
5. **设置页面 → 数据管理** 这个功能不需要(导出本月/按分类/全部数据三个按钮整体不实现)
6. 项目保存在 `007.跨端APP应用（移动端开发工程师）/`

**约定:**「完全一致」指业务行为一致,不是像素一致。移动端会做必要的响应式/导航适配(底部 tabBar 取代侧边栏、底部弹层替代居中模态、sheet 替代页面跳转 等),但每个页面承载的字段、校验、API 调用必须对得上。

## 2. 范围与非范围

### 2.1 范围内(全部来自 React 应用,1:1 移植)

| 模块 | 页面 / 端点 | 说明 |
|---|---|---|
| 鉴权 | `/login` 登录页 | 账号+密码 → 后端 `/api/auth/login` → 存 JWT |
| 鉴权 | `logout` | 后端 `/api/auth/logout` + 清本地 token |
| 鉴权 | `me()` 拉当前用户 | 启动时调,失败 toast + 跳登录 |
| 个人 | `/profile/edit` | 改昵称/头像/性别/年龄 |
| 账本 | `/books` 列表 / `/books/:uuid/members` 成员管理 |
| 账户 | `/accounts` 列表 / `/accounts/new` 新建 |
| 记账 | `/record/expense` `/record/income` 新建一条 |
| 流水 | `/transactions` 列表(筛选/编辑/删除) |
| 报表 | `/reports/monthly` 月报(折线 + 环形 + 分类饼) |
| 报表 | `/reports/yearly` 年报 |
| 首页 | `/` 当月汇总 + 快捷记一笔 |
| 设置 | `/settings` | 用户卡 + 偏好(主题/语言) + 分类管理 + 关于 + 退出 |
| i18n | zh-CN / en / zh-TW 三语字典 |
| 主题 | system / light / dark |
| 反馈 | Toast 全局通知 |

### 2.2 不实现

- **设置 → 数据管理** 三个导出按钮(本月报表 / 按分类 / 全部数据) 及其下载/导出逻辑
- 浏览器专有特性:`window.confirm` 替换为 uni-app 模态弹窗
- OCR / 导入 等移动端 V2+ 功能(React 端本身也没接,不需要)

### 2.3 移动端差异(必要适配)

| Web 形态 | Mobile 形态 | 原因 |
|---|---|---|
| 左侧 Sidebar 导航 | 底部 `tabBar`(首页 / 流水 / 报表 / 我的) + 内部次级页用 stack push | 移动端单手操作 |
| 居中模态(`fixed inset-0`) | `uni-popup` 底部抽屉 或 全屏页 | iOS/Android 习惯 |
| `<select>` 原生下拉 | uView `Picker` / 自定义 ActionSheet | 小程序不支持 `<select>` |
| Material Symbols 字体图标 | 同一字体图标(uView 内置图标 或 直接 emoji/SVG) | 跨平台一致性 |
| `<input type="date">` | uView `picker` mode=date | 小程序需专用组件 |
| `<input type="color">` | 调色盘弹层 / 预设色板 | 小程序不支持 |

## 3. 技术栈

| 层 | 选择 | 理由 |
|---|---|---|
| 框架 | uniapp (Vue 3 + Vite) | 用户指定 |
| 语言 | TypeScript | 与 React 版一致,类型安全 |
| UI 组件 | **uView UI 2.0** | 成熟、覆盖表单/列表/弹层/导航(用户已选) |
| 样式 | **UnoCSS** + presetUno | 原子化、设计令牌统一(用户已选) |
| 状态 | Pinia | Vue 3 标准,对位 React 的 AuthContext/BookContext |
| 路由 | uni-app 内置 `pages.json` + Vue Router 兜底 | uni 官方推荐 pages.json |
| 图表 | **手写 SVG**(翻译 React 版算法) | 跨端一致、零依赖(用户已选) |
| HTTP | `uni.request` 包装层 | 跨端统一 fetch |
| 存储 | `uni.setStorageSync` / `getStorageSync` | 替代 localStorage |
| API 地址 | `.env` 构建注入,`VITE_API_BASE`,默认 `http://192.168.1.100:4001` 占位 |

## 4. 目录结构

```
007.跨端APP应用（移动端开发工程师）/
├── package.json
├── tsconfig.json
├── vite.config.ts
├── index.html
├── .env.development       # 默认 API_BASE
├── .env.production
├── src/
│   ├── main.ts            # Vue 应用入口, 注册 Pinia / uView / App
│   ├── App.vue
│   ├── pages.json         # 路由 + tabBar 配置
│   ├── manifest.json      # uni-app 应用清单
│   ├── uni.scss           # 全局 SCSS 变量(主题色 / 间距)
│   ├── pages/             # ← 对位 React 的 pages/
│   │   ├── login/index.vue
│   │   ├── index/index.vue                # 首页
│   │   ├── transactions/index.vue
│   │   ├── record/expense.vue
│   │   ├── record/income.vue
│   │   ├── reports/monthly.vue
│   │   ├── reports/yearly.vue
│   │   ├── accounts/index.vue
│   │   ├── accounts/new.vue
│   │   ├── books/index.vue
│   │   ├── books/members.vue
│   │   ├── settings/index.vue             # ← 不含 数据管理
│   │   └── profile/edit.vue
│   ├── components/        # 复用组件
│   │   ├── AppHeader.vue
│   │   ├── Toast.vue
│   │   ├── DonutChart.vue
│   │   ├── LineChart.vue
│   │   ├── CategoryBadge.vue
│   │   ├── TransactionRow.vue
│   │   ├── MonthPicker.vue
│   │   └── RecordForm.vue
│   ├── api/               # 1:1 翻译 React 的 src/api/
│   │   ├── auth.ts
│   │   ├── books.ts
│   │   ├── accounts.ts
│   │   ├── records.ts
│   │   ├── categories.ts
│   │   ├── reports.ts
│   │   ├── users.ts
│   │   ├── version.ts
│   │   └── http.ts        # uni.request 封装(对位 lib/api.ts)
│   ├── stores/            # Pinia stores(对位 React Contexts)
│   │   ├── auth.ts        # AuthContext
│   │   ├── book.ts        # BookContext
│   │   ├── theme.ts       # ThemeContext
│   │   ├── language.ts    # LanguageContext
│   │   └── toast.ts
│   ├── i18n/
│   │   └── dict.ts        # 复制 React 版 zh-CN / en / zh-TW
│   ├── theme/
│   │   └── tokens.ts      # 颜色 / 字号 / 间距 design tokens
│   ├── utils/
│   │   ├── finance.ts     # 金额格式化 / 类别展示(对位 lib/finance-mappers.ts)
│   │   └── date.ts
│   └── types/
│       └── api.ts
└── README.md
```

## 5. 路由与导航

**`pages.json` tabBar:**
```json
{
  "tabBar": {
    "color": "#666",
    "selectedColor": "#2E7DE6",
    "list": [
      { "pagePath": "pages/index/index",        "text": "首页",  "iconPath": "...", "selectedIconPath": "..." },
      { "pagePath": "pages/transactions/index", "text": "流水",  "iconPath": "...", "selectedIconPath": "..." },
      { "pagePath": "pages/reports/monthly",    "text": "报表",  "iconPath": "...", "selectedIconPath": "..." },
      { "pagePath": "pages/settings/index",     "text": "我的",  "iconPath": "...", "selectedIconPath": "..." }
    ]
  }
}
```

**次级页面**(从 tab 页 push):
- `/record/expense` `/record/income` — 记账(可从首页或「+」按钮进入)
- `/accounts/new` — 新建账户
- `/books/members?uuid=…` — 账本成员
- `/profile/edit` — 编辑个人资料

**登录拦截:** Pinia `auth` store 监听 401 / token 失效 → 清 token → 跳 `/pages/login/index`(uni.navigateTo + reLaunch)。

## 6. 数据流与状态

### 6.1 Auth store(`stores/auth.ts`)

```ts
export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(uni.getStorageSync('qz_token'))
  const user  = ref<User | null>(null)

  async function login(creds) { /* POST /api/auth/login, 存 token + user */ }
  async function me()        { /* GET /api/auth/me, 失败 → onInvalid */ }
  async function logout()    { /* POST /api/auth/logout + 清 */ }

  function onInvalid() { token.value = null; user.value = null; /* reLaunch /login */ }

  // 全局注册 401 监听
  http.onAuthInvalid(() => onInvalid())
  return { token, user, login, me, logout }
})
```

### 6.2 Book store(`stores/book.ts`)

镜像 React 版 `BookContext`:
- `books: Book[]` 当前用户账本列表
- `currentBookId: string | null`
- `setCurrent(id)` 切换并持久化到 storage
- `reload()` 调 `listBooks()`
- 启动时自动选最后一个 `is_default` 或第一个

### 6.3 Theme + Language

- `theme` 三档 `system | light | dark`,持久化
- `language` 三档 `zh-CN | en | zh-TW`,持久化
- 通过 uni-app 的 CSS 变量切换 `data-theme` 属性 + Pinia 同步

### 6.4 Toast

全局 `useToast()` composable,顶部滑入,3 秒后消失。
**注意:** 微信小程序没有 Portal → 用 `<view>` + 绝对定位放 `App.vue` 顶层。

## 7. HTTP 层(`api/http.ts`)

```ts
const API_BASE = import.meta.env.VITE_API_BASE ?? 'http://192.168.1.100:4001'

class ApiError extends Error {
  constructor(public code: number | string, public message: string, public status: number) { … }
}

const authInvalidListeners = new Set<() => void>()
export function onAuthInvalid(fn: () => void) { authInvalidListeners.add(fn); return () => authInvalidListeners.delete(fn) }

export async function request<T>(path: string, options: { method?, data?, header? } = {}): Promise<T> {
  const headers: Record<string, string> = { 'Content-Type': 'application/json', ...options.header }
  const token = uni.getStorageSync('qz_token')
  if (token) headers.Authorization = `Bearer ${token}`

  const res = await new Promise<UniApp.RequestSuccessCallbackResult>((resolve, reject) => {
    uni.request({ url: API_BASE + path, method: options.method ?? 'GET', data: options.data, header: headers, success: resolve, fail: reject })
  })

  const env = (typeof res.data === 'object' && res.data !== null ? res.data : {}) as { code, message, data }
  if (env.code === 1401) authInvalidListeners.forEach(fn => fn())
  if (res.statusCode < 200 || res.statusCode >= 300 || env.code !== 0) {
    throw new ApiError(env.code ?? 'INTERNAL', env.message ?? `HTTP ${res.statusCode}`, res.statusCode)
  }
  return env.data as T
}
```

## 8. API 模块(对位 React 版)

每个模块签名 / 入参 / 出参 **逐字** 翻译:
- `auth.ts`   → `register`, `login`, `me`, `logout`, `updateProfile`
- `books.ts`  → `listBooks`, `getBook`, `createBook`, `updateBook`, `deleteBook`, `setDefaultBook`, `listMembers`, `addMember`, `updateMemberRole`, `removeMember`
- `accounts.ts`→ `listAccounts`, `getAccount`, `createAccount`, `updateAccount`, `deleteAccount`
- `records.ts`→ `listRecords`, `createRecord`, `updateRecord`, `deleteRecord`
- `categories.ts`→ `listCategories`, `createCategory`, `updateCategory`, `deleteCategory`
- `reports.ts`→ `monthly`, `yearly`
- `users.ts`  → 同 React 版(若有)
- `version.ts`→ `getVersion`

## 9. i18n

**复制 `frontend-react-java/src/i18n/dict.ts` 整文件**。三种语言字典键 1:1,只调整少量文案以适配移动端(若有)。

`t(key)` 函数完全复用 React 版行为:命中 → 返回翻译;未命中 → 回退 zh-CN;再缺 → 返回 key。

## 10. 图表(翻译 React 版)

`DonutChart.vue` / `LineChart.vue` 用 Vue 3 `<script setup>` 重写 React 版同样算法:
- 环形:`<svg>` + `path d="M…A…"` 计算每段弧长 + 中心镂空
- 折线:`<polyline>` + `<circle>` 点 + `<text>` 标签,支持触摸 hover 弹 tooltip
- 入参 segments / data 与 React 版同形

## 11. 设计令牌(`theme/tokens.ts`)

```ts
export const tokens = {
  color: {
    primary: '#2E7DE6', primaryContainer: '#D9E8FA',
    bg: '#FFFFFF', bgCard: '#FAFAFA',
    text: '#1A1A1A', textVariant: '#5F6368',
    error: '#BA1A1A', divider: '#E0E0E0',
    surface: '#F5F5F5',
  },
  // dark 模式由 data-theme="dark" + CSS 变量覆盖
  radius: { sm: 6, md: 10, lg: 16 },
  space:  { xs: 4, sm: 8, md: 12, lg: 16, xl: 24 },
}
```

## 12. 设置页(去除数据管理)

```
┌─ 用户卡片(头像 + 用户名 + 账号 + 性别 + 年龄 + 编辑)
├─ 系统偏好
│   ├─ 深色模式 [system|light|dark] segmented
│   └─ 语言 [zh-CN | en | zh-TW] picker
├─ 分类管理(expense/income tab + 列表 + 新建/编辑/删除)
├─ 关于轻账(QingZhang v… + 服务条款 / 隐私)
└─ 账号安全(退出登录)
```

**数据管理整段移除**(导出本月 / 按分类 / 全部数据 三个按钮 + 错误提示 + 文件下载逻辑 全砍)。

## 13. 跨端差异处理

| 项 | H5 | iOS / Android | 微信小程序 |
|---|---|---|---|
| `<input type="date">` | 原生 | uView picker mode=date | uView picker |
| `<input type="color">` | 原生 | 自定义色板 popup | 自定义色板 popup |
| 确认弹窗 | uni.showModal | uni.showModal | uni.showModal |
| 长按 / 触屏手势 | touch events | 原生 | 原生 |
| localStorage | ✅ | uni.storage | uni.storage |
| 文件下载(将来若用) | `<a download>` | uni.saveFile | 不支持,提示 |

> 数据管理导出虽被砍,但若日后需要,跨端需要分别处理。**当前范围无此需求**。

## 14. 测试 / 验证

- 每个 API 模块一个 vitest 单测(对位 React 版的 finance-mappers.test / category-presentation.test 等纯逻辑)
- 手测三端真实登录 → 记账 → 看报表 → 切语言/主题 → 退出 全流程
- 在 HBuilderX 真机运行 + 微信开发者工具 三端各跑一遍

## 15. 风险与备忘

- **微信小程序登录域名白名单:** 开发期在小程序后台配置 LAN IP(开发版不校验)
- **H5 跨域:** 后端已配 CORS,沿用
- **uView UI 2.x** 仅支持 Vue 3 + Vite,**确认版本对齐**(最新 2.0.36+)
- **iconfont / Material Symbols** 在小程序端要走 CDN 链接(uniapp 不打包 woff)
- **TypeScript:** vue-tsc 校验,`unbuild` / vite 编译
- **后端契约不能变:** 所有字段名、错误码(code=0 / 1401)保持原样,否则 Auth 拦截失效

## 16. 实施步骤(粗)

1. `npx degit dcloudio/uni-preset-vue#vite-ts` 初始化项目到目标目录
2. 安装 uView UI 2 / UnoCSS / Pinia / vueuse
3. 配置 `vite.config.ts`(uni-app + uView + UnoCSS preset)
4. 抄 `theme/tokens.ts` + `i18n/dict.ts` + `manifest.json` + `pages.json`
5. 实现 `api/http.ts` + 各 api 模块
6. 实现 Pinia stores
7. 实现共享 components(Toast / Donut / Line / CategoryBadge / MonthPicker / RecordForm)
8. 实现各 pages(按 React 版 1:1)
9. `pages.json` 配置 tabBar
10. 真机三端跑通核心流程

---

**等待用户审阅** — 用户批准后再进入 writing-plans 阶段。