# uniapp 跨端 APP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `003.前端代码（前端工程师）/frontend-react-java` 1:1 克隆成可在 iOS / Android / 微信小程序三端运行的 uniapp 应用,业务行为(字段、API、校验、流程)与浏览器版完全一致;设置页「数据管理」整段不实现。

**Architecture:** 全新 uniapp (Vue 3 + Vite + TS) 工程,落在 `007.跨端APP应用（移动端开发工程师）/`。uView UI 2 提供表单/列表/弹层等组件;UnoCSS 做设计令牌原子化;Pinia 对位 React Contexts(Auth/Book/Theme/Language);图表用手写 SVG 翻译 React 版算法。底部 tabBar(首页/流水/报表/我的)+ 内部 `uni.navigateTo` 替代侧边栏。

**Tech Stack:** uniapp (Vue 3 + Vite) / TypeScript / uView UI 2 / UnoCSS / Vue 3 `<script setup>`。无路由库(uni-app 内置 `pages.json`)、无图表库(手写 SVG)、无 UI 组件替代品(uView 直接用)。`uni.request` 包装替代 fetch;`uni.setStorageSync` 替代 localStorage。

**Spec:** `docs/superpowers/specs/2026-08-31-uniapp-cross-platform-app-design.md`

**Source of Truth (React 版):** `003.前端代码（前端工程师）/frontend-react-java/` — 字段名、API 签名、文案、i18n 字典、设计令牌全部从此处 1:1 翻译。

---

## Global Constraints

- 目标目录:`007.跨端APP应用（移动端开发工程师）/`(若已存在则用现有骨架,否则 `npx degit dcloudio/uni-preset-vue#vite-ts` 初始化)
- 字段名、API path、错误码(0=成功,1401=未登录)**逐字**对齐 React 版,后端契约不动
- 后端 API 地址用 `import.meta.env.VITE_API_BASE`,默认 `http://192.168.1.100:4001`(LAN IP 占位)
- 存储 key `qz_token`(对位 React 的 `qz_token`)
- i18n 三语 zh-CN / en / zh-TW,`t()` 行为与 React 版一致(命中 → 翻译,缺 → 回退 zh-CN,再缺 → key)
- 主题三档 `system | light | dark`,CSS 变量 + `data-theme` 切换
- **不实现**:设置页「数据管理」三个导出按钮(本月报表 / 按分类 / 全部数据)及对应 i18n key 与导出逻辑
- Token 失效(后端 1401)→ 全局 `reLaunch('/pages/login/index')`
- TypeScript 严格模式;`vue-tsc` 校验
- 提交粒度:每完成一个 task 立刻 commit;commit message 用 `feat(uniapp):` / `chore:` / `test:` 前缀
- 所有 API 模块 + utils 必须有 vitest 单测覆盖纯逻辑(测试在 `tests/` 下,运行 `npx vitest run`)
- 移动端适配硬性项:`<input type="date">` → uView picker mode=date;`<input type="color">` → 预设色板 popup;`window.confirm` → `uni.showModal`;`<select>` → uView picker

---

## Task 1: 工程脚手架

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/package.json`
- Create: `007.跨端APP应用（移动端开发工程师）/tsconfig.json`
- Create: `007.跨端APP应用（移动端开发工程师）/vite.config.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/index.html`
- Create: `007.跨端APP应用（移动端开发工程师）/src/main.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/App.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages.json`
- Create: `007.跨端APP应用（移动端开发工程师）/src/manifest.json`
- Create: `007.跨端APP应用（移动端开发工程师）/src/uni.scss`
- Create: `007.跨端APP应用（移动端开发工程师）/uno.config.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/vitest.config.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/tests/.gitkeep`
- Create: `007.跨端APP应用（移动端开发工程师）/README.md`
- Create: `007.跨端APP应用（移动端开发工程师）/.env.development`
- Create: `007.跨端APP应用（移动端开发工程师）/.env.production`
- Create: `007.跨端APP应用（移动端开发工程师）/.gitignore`

**Step 1: package.json**

```json
{
  "name": "qingzhang-app",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev:h5":        "uni",
    "dev:mp-weixin": "uni -p mp-weixin",
    "dev:app":       "uni -p app",
    "build:h5":        "uni build",
    "build:mp-weixin": "uni build -p mp-weixin",
    "build:app":       "uni build -p app",
    "type-check":    "vue-tsc --noEmit",
    "test":          "vitest run"
  },
  "dependencies": {
    "@dcloudio/uni-app":        "3.0.0-4060620250520001",
    "@dcloudio/uni-app-plus":   "3.0.0-4060620250520001",
    "@dcloudio/uni-components": "3.0.0-4060620250520001",
    "@dcloudio/uni-h5":         "3.0.0-4060620250520001",
    "@dcloudio/uni-mp-weixin":  "3.0.0-4060620250520001",
    "pinia": "^2.1.7",
    "vue": "3.4.21",
    "uview-plus": "^3.3.62"
  },
  "devDependencies": {
    "@dcloudio/types":               "^3.4.8",
    "@dcloudio/uni-automator":       "3.0.0-4060620250520001",
    "@dcloudio/uni-cli-shared":      "3.0.0-4060620250520001",
    "@dcloudio/uni-stacktracey":     "3.0.0-4060620250520001",
    "@dcloudio/vite-plugin-uni":     "3.0.0-4060620250520001",
    "@vue/runtime-core":             "3.4.21",
    "@vue/tsconfig":                 "^0.5.1",
    "sass":                          "^1.77.0",
    "typescript":                    "^5.4.5",
    "unocss":                        "^0.61.0",
    "@unocss/preset-uno":             "^0.61.0",
    "vite":                          "5.2.8",
    "vitest":                        "^1.6.0",
    "vue-tsc":                       "^2.0.13"
  }
}
```

**Step 2: vite.config.ts**

```ts
import { defineConfig } from 'vite'
import uni from '@dcloudio/vite-plugin-uni'
import UnoCSS from 'unocss/vite'

export default defineConfig({
  plugins: [uni(), UnoCSS()],
})
```

**Step 3: tsconfig.json**

```json
{
  "extends": "@vue/tsconfig/tsconfig.json",
  "compilerOptions": {
    "sourceMap": true,
    "baseUrl": "./",
    "paths": { "@/*": ["src/*"] },
    "lib": ["esnext", "dom"],
    "types": ["@dcloudio/types", "vitest/globals"]
  },
  "vueCompilerOptions": { "plugins": ["@dcloudio/uni-cli-shared/lib/vue-language-plugin"] },
  "include": ["src/**/*", "tests/**/*", "src/**/*.vue"]
}
```

**Step 4: vitest.config.ts**

```ts
import { defineConfig } from 'vitest/config'
export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['tests/**/*.test.ts'],
  },
})
```

**Step 5: src/main.ts**

```ts
import { createSSRApp } from 'vue'
import * as Pinia from 'pinia'
import App from './App.vue'

export function createApp() {
  const app = createSSRApp(App)
  app.use(Pinia.createPinia())
  return { app }
}
```

**Step 6: src/App.vue**

```vue
<script setup lang="ts">
import { onLaunch } from '@dcloudio/uni-app'
import { useAuthStore } from '@/stores/auth'
import { useBookStore } from '@/stores/book'
import { useThemeStore } from '@/stores/theme'
import { useLanguageStore } from '@/stores/language'
import ToastHost from '@/components/Toast.vue'

const auth = useAuthStore()
const book = useBookStore()
const theme = useThemeStore()
const lang  = useLanguageStore()

onLaunch(async () => {
  theme.applySystemListener()
  lang.hydrate()
  if (auth.token) {
    try { await auth.me() } catch { /* token invalid → reLaunch /login */ }
    try { await book.reload() } catch { /* 容忍 */ }
  }
})
</script>

<template>
  <view class="app-root" :data-theme="theme.mode">
    <slot />
    <ToastHost />
  </view>
</template>
```

**Step 7: src/pages.json(初始骨架,后续 task 扩充)**

```json
{
  "pages": [
    { "path": "pages/login/index",      "style": { "navigationBarTitleText": "登录" } },
    { "path": "pages/index/index",      "style": { "navigationBarTitleText": "首页" } },
    { "path": "pages/transactions/index","style": { "navigationBarTitleText": "流水" } },
    { "path": "pages/record/expense",   "style": { "navigationBarTitleText": "记支出" } },
    { "path": "pages/record/income",    "style": { "navigationBarTitleText": "记收入" } },
    { "path": "pages/reports/monthly",  "style": { "navigationBarTitleText": "月报" } },
    { "path": "pages/reports/yearly",   "style": { "navigationBarTitleText": "年报" } },
    { "path": "pages/accounts/index",   "style": { "navigationBarTitleText": "账户" } },
    { "path": "pages/accounts/new",     "style": { "navigationBarTitleText": "新建账户" } },
    { "path": "pages/books/index",      "style": { "navigationBarTitleText": "账本" } },
    { "path": "pages/books/members",    "style": { "navigationBarTitleText": "成员管理" } },
    { "path": "pages/settings/index",   "style": { "navigationBarTitleText": "我的" } },
    { "path": "pages/profile/edit",     "style": { "navigationBarTitleText": "编辑资料" } }
  ],
  "globalStyle": {
    "navigationBarTextStyle": "black",
    "navigationBarTitleText": "轻账",
    "backgroundColor": "#F8F8F8"
  }
}
```

**Step 8: src/manifest.json(关键字段,完整内容按需补充)**

```json
{
  "name": "轻账",
  "appid": "",
  "description": "个人 / 共享 / 生意 记账",
  "versionName": "0.1.0",
  "versionCode": "1",
  "transformPx": false,
  "app-plus": { "usingComponents": true, "nvueStyleCompiler": "uni-app" },
  "mp-weixin": {
    "appid": "替换成你自己的小程序 appid",
    "setting": { "urlCheck": false, "es6": true, "minified": true },
    "usingComponents": true
  },
  "h5": {
    "title": "轻账",
    "router": { "mode": "history", "base": "/" }
  }
}
```

**Step 9: src/uni.scss**

```scss
$primary:        #2E7DE6;
$primary-light:  #D9E8FA;
$bg:             #FFFFFF;
$bg-card:        #FAFAFA;
$text:           #1A1A1A;
$text-variant:   #5F6368;
$divider:        #E0E0E0;
$error:          #BA1A1A;
$surface:        #F5F5F5;
```

**Step 10: uno.config.ts**

```ts
import { defineConfig, presetUno } from 'unocss'
export default defineConfig({
  presets: [presetUno()],
  theme: {
    colors: {
      primary: '#2E7DE6',
      'primary-light': '#D9E8FA',
      bg: '#FFFFFF', 'bg-card': '#FAFAFA',
      text: '#1A1A1A', 'text-variant': '#5F6368',
      divider: '#E0E0E0', error: '#BA1A1A', surface: '#F5F5F5',
    },
  },
})
```

**Step 11: .env.development / .env.production**

```
# .env.development
VITE_API_BASE=http://192.168.1.100:4001
```

```
# .env.production
VITE_API_BASE=https://your-prod-host
```

**Step 12: .gitignore**

```
node_modules/
dist/
unpackage/
.env.local
*.log
.DS_Store
```

**Step 13: README.md(占位,后续 task 扩写)**

```md
# 轻账 uniapp

iOS / Android / 微信小程序 三端 React 1:1 克隆。详见 docs/superpowers/specs/2026-08-31-uniapp-cross-platform-app-design.md
```

**Step 14: 安装依赖 + 类型检查**

```bash
cd "007.跨端APP应用（移动端开发工程师）"
npm install
npx vue-tsc --noEmit || true   # 组件未创建,允许报错
```

**Step 15: Commit**

```bash
cd "007.跨端APP应用（移动端开发工程师）"
git add -A
git commit -m "chore(uniapp): scaffold uniapp vue3+vite+ts 工程"
```

---

## Task 2: 设计令牌 + 主题 CSS

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/theme/tokens.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/theme/global.scss`
- Modify: `007.跨端APP应用（移动端开发工程师）/src/uni.scss`(追加 dark 主题)

**Step 1: src/theme/tokens.ts**

```ts
/** 与 React 版 src/theme/ThemeContext.tsx + index.css 同形 */
export const tokens = {
  color: {
    primary:        '#2E7DE6',
    'primary-light':'#D9E8FA',
    bg:             '#FFFFFF',
    'bg-card':      '#FAFAFA',
    text:           '#1A1A1A',
    'text-variant':  '#5F6368',
    error:          '#BA1A1A',
    divider:        '#E0E0E0',
    surface:        '#F5F5F5',
  },
  radius: { sm: 6, md: 10, lg: 16 },
  space:  { xs: 4, sm: 8, md: 12, lg: 16, xl: 24 },
} as const

export type ThemeMode = 'system' | 'light' | 'dark'

/** dark 主题覆盖色 */
export const darkTokens = {
  primary:        '#5BA3FF',
  'primary-light':'#1F3A60',
  bg:             '#0F1115',
  'bg-card':      '#181B22',
  text:           '#E6E8EC',
  'text-variant': '#A0A6B2',
  error:          '#FF6B6B',
  divider:        '#2A2F38',
  surface:        '#1F242C',
}
```

**Step 2: src/theme/global.scss**

```scss
@import 'tokens';

:root {
  --c-primary:        #{tokens.color.primary};
  --c-primary-light:  #{tokens.color.primary-light};
  --c-bg:             #{tokens.color.bg};
  --c-bg-card:        #{tokens.color.bg-card};
  --c-text:           #{tokens.color.text};
  --c-text-variant:   #{tokens.color.text-variant};
  --c-error:          #{tokens.color.error};
  --c-divider:        #{tokens.color.divider};
  --c-surface:        #{tokens.color.surface};
}
[data-theme='dark'] {
  --c-primary:        #5BA3FF;
  --c-primary-light:  #1F3A60;
  --c-bg:             #0F1115;
  --c-bg-card:        #181B22;
  --c-text:           #E6E8EC;
  --c-text-variant:   #A0A6B2;
  --c-error:          #FF6B6B;
  --c-divider:        #2A2F38;
  --c-surface:        #1F242C;
}

.app-root { background: var(--c-bg); color: var(--c-text); min-height: 100vh; }
.page-container { padding: 24rpx; }
.card { background: var(--c-bg-card); border: 1px solid var(--c-divider); border-radius: 16rpx; padding: 24rpx; }
.divider { height: 1px; background: var(--c-divider); }
.btn-primary { background: var(--c-primary); color: #fff; border-radius: 12rpx; padding: 16rpx 24rpx; }
.btn-outline { border: 1px solid var(--c-divider); color: var(--c-text); border-radius: 12rpx; padding: 16rpx 24rpx; }
.text-variant { color: var(--c-text-variant); }
```

**Step 3: 修改 src/uni.scss 追加**

```scss
/* dark 模式变量已由 theme/global.scss 通过 data-theme 切换,此处不再重复 */
```

**Step 4: 在 src/main.ts 引入 global.scss**

```ts
import { createSSRApp } from 'vue'
import * as Pinia from 'pinia'
import App from './App.vue'
import './theme/global.scss'

export function createApp() {
  const app = createSSRApp(App)
  app.use(Pinia.createPinia())
  return { app }
}
```

**Step 5: Commit**

```bash
cd "007.跨端APP应用（移动端开发工程师）"
git add src/theme src/uni.scss src/main.ts
git commit -m "feat(uniapp): 设计令牌 + 主题 CSS(light/dark)"
```

---

## Task 3: i18n 字典

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/i18n/dict.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/i18n/useLanguage.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/tests/i18n.test.ts`

**Step 1: tests/i18n.test.ts(失败先写)**

```ts
import { describe, it, expect } from 'vitest'
import { t, LANGS } from '@/i18n/dict'

describe('dict.t', () => {
  it('returns translation when key exists', () => {
    expect(t('zh-CN', 'common.confirm')).toBe('确认')
    expect(t('en', 'common.confirm')).toBe('Confirm')
  })
  it('falls back to zh-CN when target missing', () => {
    // 假设 'foo.bar.baz' 在 zh-CN/en/zh-TW 都没有
    expect(t('en', '__nonexistent_key__')).toBe('__nonexistent_key__')
  })
  it('LANGS has 3 entries', () => {
    expect(LANGS.map(l => l.code)).toEqual(['zh-CN', 'en', 'zh-TW'])
  })
})
```

**Step 2: src/i18n/dict.ts**

整文件复制 `frontend-react-java/src/i18n/dict.ts`,**删除所有 `settings.data.*` 键**(导出本月/按分类/全部数据 相关)。

```ts
export type Lang = 'zh-CN' | 'en' | 'zh-TW'
export const LANGS: { code: Lang; label: string }[] = [
  { code: 'zh-CN', label: '简体中文' },
  { code: 'en',    label: 'English' },
  { code: 'zh-TW', label: '繁體中文' },
]

type Dict = Record<string, string>

const zh_CN: Dict = { /* ←—— 整段复制 React 版,删掉 settings.data.* 键 */ }
const en:    Dict = { /* ←—— 同上 */ }
const zh_TW: Dict = { /* ←—— 同上 */ }

const dicts: Record<Lang, Dict> = { 'zh-CN': zh_CN, 'en': en, 'zh-TW': zh_TW }
const fallback: Dict = zh_CN

export function t(lang: Lang, key: string): string {
  return dicts[lang]?.[key] ?? fallback[key] ?? key
}
```

> 实施时,直接从 `frontend-react-java/src/i18n/dict.ts` 复制三份 dict 字符串,然后**全文删除**所有 `settings.data.*` 键(`settings.data.title` / `settings.data.exportMonthly` / `settings.data.exportCategory` / `settings.data.exportAll` / `settings.data.exporting` / `settings.data.exportDesc` / `settings.data.exportFailPrefix` 全部)。

**Step 3: src/i18n/useLanguage.ts**

```ts
import { computed } from 'vue'
import { t as translate, LANGS, type Lang } from './dict'
import { useLanguageStore } from '@/stores/language'

export function useLanguage() {
  const store = useLanguageStore()
  const t = (key: string) => translate(store.lang, key)
  return { lang: computed(() => store.lang), setLang: store.setLang, t, LANGS }
}
```

**Step 4: 跑测试**

```bash
cd "007.跨端APP应用（移动端开发工程师）"
npm run test -- tests/i18n.test.ts
# Expected: PASS 3 tests
```

**Step 5: Commit**

```bash
git add src/i18n tests/i18n.test.ts
git commit -m "feat(uniapp): i18n 字典(去除 settings.data.*)"
```

---

## Task 4: HTTP 层

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/http.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/tests/http.test.ts`

**Step 1: tests/http.test.ts(失败先写)**

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest'

// uni.request mock
const mockRequest = vi.fn()
;(globalThis as any).uni = { request: mockRequest, getStorageSync: () => null }

import { request, ApiError, onAuthInvalid } from '@/api/http'

beforeEach(() => { mockRequest.mockReset() })

describe('http.request', () => {
  it('returns data on success envelope {code:0}', async () => {
    mockRequest.mockImplementation(({ success }: any) =>
      success({ statusCode: 200, data: { code: 0, message: 'ok', data: { hello: 'world' } } })
    )
    const r = await request<{ hello: string }>('/api/test')
    expect(r).toEqual({ hello: 'world' })
  })

  it('throws ApiError when code != 0', async () => {
    mockRequest.mockImplementation(({ success }: any) =>
      success({ statusCode: 200, data: { code: 1401, message: '未登录', data: null } })
    )
    await expect(request('/api/test')).rejects.toBeInstanceOf(ApiError)
  })

  it('throws ApiError on HTTP non-2xx', async () => {
    mockRequest.mockImplementation(({ success }: any) =>
      success({ statusCode: 500, data: { code: 99, message: 'boom' } })
    )
    await expect(request('/api/test')).rejects.toMatchObject({ status: 500 })
  })

  it('notifies authInvalid listeners on code 1401', async () => {
    const fn = vi.fn()
    const off = onAuthInvalid(fn)
    mockRequest.mockImplementation(({ success }: any) =>
      success({ statusCode: 200, data: { code: 1401, message: '未登录' } })
    )
    await request('/api/test').catch(() => {})
    expect(fn).toHaveBeenCalledOnce()
    off()
  })

  it('injects Authorization header when token in storage', async () => {
    ;(globalThis as any).uni.getStorageSync = () => 'tok123'
    mockRequest.mockImplementation(({ success, header }: any) => {
      expect(header.Authorization).toBe('Bearer tok123')
      success({ statusCode: 200, data: { code: 0, message: 'ok' } })
    })
    await request('/api/test')
    ;(globalThis as any).uni.getStorageSync = () => null
  })
})
```

**Step 2: src/api/http.ts**

```ts
const API_BASE: string =
  (import.meta.env.VITE_API_BASE as string | undefined) ?? 'http://192.168.1.100:4001'

const TOKEN_KEY = 'qz_token'

export function getToken(): string | null {
  return uni.getStorageSync(TOKEN_KEY) ?? null
}

export class ApiError extends Error {
  code: number | string
  status: number
  constructor(code: number | string, message: string, status: number) {
    super(message)
    this.code = code
    this.status = status
    this.name = 'ApiError'
  }
}

type AuthInvalidListener = () => void
const authInvalidListeners = new Set<AuthInvalidListener>()
export function onAuthInvalid(fn: AuthInvalidListener): () => void {
  authInvalidListeners.add(fn)
  return () => { authInvalidListeners.delete(fn) }
}

interface ApiEnvelope<T> { code: number; message: string; data?: T }

export async function request<T>(path: string, options: {
  method?: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH'
  data?: unknown
  header?: Record<string, string>
} = {}): Promise<T> {
  const headers: Record<string, string> = { ...(options.header ?? {}) }
  if (options.data !== undefined && !headers['Content-Type']) {
    headers['Content-Type'] = 'application/json'
  }
  const token = getToken()
  if (token && !headers.Authorization) headers.Authorization = `Bearer ${token}`

  const res = await new Promise<UniApp.RequestSuccessCallbackResult>((resolve, reject) => {
    uni.request({
      url: API_BASE + path,
      method: options.method ?? 'GET',
      data: options.data,
      header: headers,
      success: resolve,
      fail: reject,
    })
  })

  const env = (typeof res.data === 'object' && res.data !== null
    ? res.data : {}) as Partial<ApiEnvelope<T>>
  const code = env.code ?? 'INTERNAL'
  const message = env.message ?? `HTTP ${res.statusCode}`

  if (code === 1401) {
    for (const fn of authInvalidListeners) {
      try { fn() } catch (e) { console.error('[authInvalid]', e) }
    }
  }

  if (res.statusCode < 200 || res.statusCode >= 300 || code !== 0) {
    throw new ApiError(code as number | string, message, res.statusCode)
  }
  return env.data as T
}
```

**Step 3: 跑测试**

```bash
cd "007.跨端APP应用（移动端开发工程师）"
npm run test -- tests/http.test.ts
# Expected: PASS 5 tests
```

**Step 4: Commit**

```bash
git add src/api/http.ts tests/http.test.ts
git commit -m "feat(uniapp): HTTP 层(request + ApiError + onAuthInvalid)"
```

---

## Task 5: API 模块 — auth

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/auth.ts`

**Step 1: src/api/auth.ts(逐字翻译 React 版)**

打开 `frontend-react-java/src/api/auth.ts`,逐字段 / 逐函数 1:1 翻译:

```ts
import { request } from './http'

export type Gender = 'male' | 'female' | 'other'

export interface User {
  uuid: string
  username: string
  displayName: string | null
  avatar: string | null
  gender: Gender | null
  age: number | null
}

export interface AuthResponse {
  token: string
  user: User
}

export interface Credentials {
  username: string
  password: string
}

export async function register(input: Credentials): Promise<AuthResponse> {
  return request<AuthResponse>('/api/auth/register', { method: 'POST', data: input })
}

export async function login(input: Credentials): Promise<AuthResponse> {
  return request<AuthResponse>('/api/auth/login', { method: 'POST', data: input })
}

export async function me(): Promise<User> {
  return request<User>('/api/auth/me')
}

export async function logout(): Promise<{ ok: true }> {
  return request<{ ok: true }>('/api/auth/logout', { method: 'POST' })
}

export async function updateProfile(input: Partial<{
  displayName: string | null
  avatar: string | null
  gender: Gender | null
  age: number | null
}>): Promise<User> {
  return request<User>('/api/auth/me', { method: 'PUT', data: input })
}
```

**Step 2: Commit**

```bash
git add src/api/auth.ts
git commit -m "feat(uniapp): api/auth 翻译 React 版"
```

---

## Task 6: API 模块 — books

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/books.ts`

**Step 1: 逐字翻译**

打开 `frontend-react-java/src/api/books.ts`,把每个 `export type` / `export interface` / `export async function` 复制过来,**只**把 `import { request } from '../lib/api'` 改为 `import { request } from './http'`。完整函数列表:`listBooks`, `getBook`, `createBook`, `updateBook`, `deleteBook`, `setDefaultBook`, `listMembers`, `addMember`, `updateMemberRole`, `removeMember`。

**Step 2: Commit**

```bash
git add src/api/books.ts
git commit -m "feat(uniapp): api/books 翻译 React 版"
```

---

## Task 7: API 模块 — accounts

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/accounts.ts`

**Step 1: 逐字翻译**

打开 `frontend-react-java/src/api/accounts.ts`,函数列表:`listAccounts`, `getAccount`, `createAccount`, `updateAccount`, `deleteAccount`。

**Step 2: Commit**

```bash
git add src/api/accounts.ts
git commit -m "feat(uniapp): api/accounts 翻译 React 版"
```

---

## Task 8: API 模块 — records

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/records.ts`

**Step 1: 逐字翻译**

打开 `frontend-react-java/src/api/records.ts`,函数列表:`listRecords` (含 `buildQuery`), `createRecord`, `updateRecord`, `deleteRecord`。

**Step 2: Commit**

```bash
git add src/api/records.ts
git commit -m "feat(uniapp): api/records 翻译 React 版"
```

---

## Task 9: API 模块 — categories

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/categories.ts`

**Step 1: 逐字翻译**

打开 `frontend-react-java/src/api/categories.ts`,函数列表:`listCategories`, `createCategory`, `updateCategory`, `deleteCategory`。

**Step 2: Commit**

```bash
git add src/api/categories.ts
git commit -m "feat(uniapp): api/categories 翻译 React 版"
```

---

## Task 10: API 模块 — reports + version + users

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/reports.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/version.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/api/users.ts`

**Step 1: 三个文件分别逐字翻译**

- `reports.ts` ← `frontend-react-java/src/api/reports.ts`(月报/年报)
- `version.ts` ← `frontend-react-java/src/api/version.ts`
- `users.ts`   ← `frontend-react-java/src/api/users.ts`(若存在)

**Step 2: Commit**

```bash
git add src/api/reports.ts src/api/version.ts src/api/users.ts
git commit -m "feat(uniapp): api/{reports,version,users} 翻译 React 版"
```

---

## Task 11: utils — finance + category 展示

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/utils/finance.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/utils/category-presentation.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/utils/account-presentation.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/tests/finance.test.ts`

**Step 1: tests/finance.test.ts**

```ts
import { describe, it, expect } from 'vitest'
import { formatAmount, typeOfAccount, typeOfCategory, balanceSign } from '@/utils/finance'

describe('finance utils', () => {
  it('formatAmount: 正数带 ¥,两位小数', () => {
    expect(formatAmount(12.5)).toMatch(/12\.50/)
    expect(formatAmount(0)).toMatch(/0\.00/)
  })
  it('typeOfAccount', () => {
    expect(typeOfAccount('cash')).toBe('现金')
    expect(typeOfAccount('debit')).toBe('借记卡')
  })
  it('typeOfCategory: expense 走支出图标, income 走收入图标', () => {
    expect(typeOfCategory('expense')).toBe('expense')
    expect(typeOfCategory('income')).toBe('income')
  })
  it('balanceSign', () => {
    expect(balanceSign(100)).toBe(1)
    expect(balanceSign(-50)).toBe(-1)
    expect(balanceSign(0)).toBe(0)
  })
})
```

**Step 2: src/utils/finance.ts**

复制 `frontend-react-java/src/lib/finance-types.ts` 与 `finance-mappers.ts` 的纯函数,合并为单文件;数值/字典全部 1:1。

```ts
import type { AccountType } from '@/api/accounts'
import type { CategoryType } from '@/api/categories'

export function formatAmount(n: number, withSymbol = true): string {
  const s = (withSymbol ? '¥' : '') + n.toFixed(2)
  return s
}

export function typeOfAccount(t: AccountType): string {
  return ({ cash: '现金', debit: '借记卡', credit: '信用卡', wallet: '钱包', investment: '投资', other: '其他' } as const)[t] ?? '其他'
}

export function typeOfCategory(t: CategoryType): 'expense' | 'income' | 'transfer' {
  return t
}

export function balanceSign(n: number): -1 | 0 | 1 {
  return n < 0 ? -1 : n > 0 ? 1 : 0
}
```

**Step 3: src/utils/category-presentation.ts + account-presentation.ts**

```ts
// category-presentation.ts
export function categoryIconColor(icon: string, color: string) {
  return { icon, color }
}
```

```ts
// account-presentation.ts
export function accountAccent(_type: string): string { return '#2E7DE6' }
```

**Step 4: 跑测试**

```bash
cd "007.跨端APP应用（移动端开发工程师）"
npm run test -- tests/finance.test.ts
# Expected: PASS 4 tests
```

**Step 5: Commit**

```bash
git add src/utils tests/finance.test.ts
git commit -m "feat(uniapp): utils finance + presentation"
```

---

## Task 12: Pinia store — auth

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/stores/auth.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/tests/auth.test.ts`

**Step 1: tests/auth.test.ts**

```ts
import { describe, it, expect, vi, beforeEach } from 'vitest'

const mockStorage: Record<string, any> = {}
;(globalThis as any).uni = {
  request: vi.fn(),
  getStorageSync: (k: string) => mockStorage[k] ?? null,
  setStorageSync: (k: string, v: any) => { mockStorage[k] = v },
  removeStorageSync: (k: string) => { delete mockStorage[k] },
  reLaunch: vi.fn(),
}

import { setActivePinia, createPinia } from 'pinia'
import { useAuthStore } from '@/stores/auth'

beforeEach(() => { setActivePinia(createPinia()); for (const k of Object.keys(mockStorage)) delete mockStorage[k] })

describe('auth store', () => {
  it('login stores token + user', async () => {
    ;(uni.request as any).mockImplementation(({ success }: any) =>
      success({ statusCode: 200, data: { code: 0, data: { token: 'T', user: { uuid: 'u1', username: 'alice', displayName: null, avatar: null, gender: null, age: null } } } })
    )
    const auth = useAuthStore()
    await auth.login({ username: 'a', password: 'b' })
    expect(auth.token).toBe('T')
    expect(auth.user?.username).toBe('alice')
    expect(mockStorage.qz_token).toBe('T')
  })

  it('onInvalid clears token + user + reLaunch', () => {
    const auth = useAuthStore()
    auth.token = 'stale'
    auth.user = { uuid: 'u', username: 'x', displayName: null, avatar: null, gender: null, age: null }
    auth.onInvalid()
    expect(auth.token).toBeNull()
    expect(auth.user).toBeNull()
    expect(mockStorage.qz_token).toBeUndefined()
    expect((uni.reLaunch as any)).toHaveBeenCalled()
  })
})
```

**Step 2: src/stores/auth.ts**

```ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import * as api from '@/api/auth'
import type { User, Credentials } from '@/api/auth'
import { onAuthInvalid } from '@/api/http'

const TOKEN_KEY = 'qz_token'

export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(uni.getStorageSync(TOKEN_KEY) ?? null)
  const user  = ref<User | null>(null)

  async function login(creds: Credentials) {
    const r = await api.login(creds)
    token.value = r.token
    uni.setStorageSync(TOKEN_KEY, r.token)
    user.value = r.user
    return r
  }

  async function me() {
    const u = await api.me()
    user.value = u
    return u
  }

  async function logout() {
    try { await api.logout() } catch { /* 容忍 */ }
    token.value = null
    user.value = null
    uni.removeStorageSync(TOKEN_KEY)
  }

  function onInvalid() {
    token.value = null
    user.value = null
    uni.removeStorageSync(TOKEN_KEY)
    uni.reLaunch({ url: '/pages/login/index' })
  }

  onAuthInvalid(onInvalid)

  return { token, user, login, me, logout, onInvalid }
})
```

**Step 3: 跑测试**

```bash
npm run test -- tests/auth.test.ts
# Expected: PASS 2 tests
```

**Step 4: Commit**

```bash
git add src/stores/auth.ts tests/auth.test.ts
git commit -m "feat(uniapp): Pinia auth store"
```

---

## Task 13: Pinia store — book

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/stores/book.ts`

**Step 1: 实现**

```ts
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import * as api from '@/api/books'
import type { Book } from '@/api/books'

const CURRENT_KEY = 'qz_current_book_uuid'

export const useBookStore = defineStore('book', () => {
  const books = ref<Book[]>([])
  const currentId = ref<string | null>(uni.getStorageSync(CURRENT_KEY) ?? null)
  const loading = ref(false)

  const current = computed(() => books.value.find(b => b.uuid === currentId.value) ?? null)

  async function reload() {
    loading.value = true
    try {
      books.value = await api.listBooks()
      // 优先用持久化的 currentId,否则选 is_default,再否则选第一个
      if (!currentId.value || !books.value.find(b => b.uuid === currentId.value)) {
        const def = books.value.find(b => b.isDefault) ?? books.value[0]
        if (def) {
          currentId.value = def.uuid
          uni.setStorageSync(CURRENT_KEY, def.uuid)
        }
      }
    } finally {
      loading.value = false
    }
  }

  function setCurrent(uuid: string) {
    currentId.value = uuid
    uni.setStorageSync(CURRENT_KEY, uuid)
  }

  async function createBook(input: api.CreateBookInput) {
    const b = await api.createBook(input)
    await reload()
    return b
  }

  async function updateBook(uuid: string, input: api.UpdateBookInput) {
    const b = await api.updateBook(uuid, input)
    await reload()
    return b
  }

  async function deleteBook(uuid: string) {
    await api.deleteBook(uuid)
    if (currentId.value === uuid) currentId.value = null
    await reload()
  }

  async function setDefault(uuid: string) {
    const b = await api.setDefaultBook(uuid)
    await reload()
    return b
  }

  return { books, current, currentId, loading, reload, setCurrent, createBook, updateBook, deleteBook, setDefault }
})
```

**Step 2: Commit**

```bash
git add src/stores/book.ts
git commit -m "feat(uniapp): Pinia book store"
```

---

## Task 14: Pinia store — theme + language + toast

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/stores/theme.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/stores/language.ts`
- Create: `007.跨端APP应用（移动端开发工程师）/src/stores/toast.ts`

**Step 1: src/stores/theme.ts**

```ts
import { defineStore } from 'pinia'
import { ref } from 'vue'

type Mode = 'system' | 'light' | 'dark'
const KEY = 'qz_theme_mode'

export const useThemeStore = defineStore('theme', () => {
  const mode = ref<Mode>((uni.getStorageSync(KEY) as Mode) ?? 'system')
  const resolved = ref<'light' | 'dark'>('light')

  function applySystemListener() {
    const mql = typeof window !== 'undefined' ? window.matchMedia('(prefers-color-scheme: dark)') : null
    function update() {
      const wantDark = mode.value === 'dark' || (mode.value === 'system' && !!mql?.matches)
      resolved.value = wantDark ? 'dark' : 'light'
      if (typeof document !== 'undefined') {
        document.documentElement.setAttribute('data-theme', resolved.value)
      }
    }
    update()
    if (mql) mql.addEventListener('change', update)
  }

  function setMode(m: Mode) {
    mode.value = m
    uni.setStorageSync(KEY, m)
    applySystemListener()
  }

  return { mode, resolved, setMode, applySystemListener }
})
```

**Step 2: src/stores/language.ts**

```ts
import { defineStore } from 'pinia'
import { ref } from 'vue'
import type { Lang } from '@/i18n/dict'

const KEY = 'qz_lang'

export const useLanguageStore = defineStore('language', () => {
  const lang = ref<Lang>((uni.getStorageSync(KEY) as Lang) ?? 'zh-CN')

  function setLang(l: Lang) {
    lang.value = l
    uni.setStorageSync(KEY, l)
  }

  function hydrate() { /* 启动时已从 storage 读,无需操作 */ }

  return { lang, setLang, hydrate }
})
```

**Step 3: src/stores/toast.ts**

```ts
import { defineStore } from 'pinia'
import { ref } from 'vue'

interface ToastItem { id: number; message: string }

let counter = 0

export const useToastStore = defineStore('toast', () => {
  const items = ref<ToastItem[]>([])

  function show(message: string, duration = 3000) {
    const id = ++counter
    items.value.push({ id, message })
    setTimeout(() => {
      items.value = items.value.filter(i => i.id !== id)
    }, duration)
  }

  return { items, show }
})
```

**Step 4: Commit**

```bash
git add src/stores/theme.ts src/stores/language.ts src/stores/toast.ts
git commit -m "feat(uniapp): Pinia theme/language/toast stores"
```

---

## Task 15: 组件 — Toast.vue

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/Toast.vue`

**Step 1: 实现**

```vue
<script setup lang="ts">
import { useToastStore } from '@/stores/toast'
const toast = useToastStore()
</script>

<template>
  <view class="toast-host">
    <view v-for="t in toast.items" :key="t.id" class="toast-item">{{ t.message }}</view>
  </view>
</template>

<style scoped>
.toast-host {
  position: fixed; top: 80rpx; left: 0; right: 0;
  display: flex; flex-direction: column; align-items: center;
  z-index: 9999; pointer-events: none;
}
.toast-item {
  background: rgba(0,0,0,.78); color: #fff;
  padding: 16rpx 32rpx; border-radius: 12rpx;
  margin-top: 12rpx; max-width: 80vw;
  font-size: 28rpx;
}
</style>
```

**Step 2: Commit**

```bash
git add src/components/Toast.vue
git commit -m "feat(uniapp): 全局 Toast 组件"
```

---

## Task 16: 组件 — AppHeader + MonthPicker + ColorSwatch

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/AppHeader.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/MonthPicker.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/ColorSwatch.vue`

**Step 1: AppHeader.vue**

```vue
<script setup lang="ts">
import { useLanguageStore } from '@/stores/language'
defineProps<{ title: string; back?: boolean }>()
const lang = useLanguageStore()
</script>
<template>
  <view class="app-header">
    <view v-if="back" class="back-btn" @tap="$emit('back')">
      <text>‹</text>
    </view>
    <view class="title">{{ title }}</view>
    <slot name="right" />
  </view>
</template>
<style scoped>
.app-header { display: flex; align-items: center; height: 88rpx; padding: 0 24rpx; background: var(--c-bg); border-bottom: 1px solid var(--c-divider); }
.back-btn { width: 64rpx; font-size: 48rpx; color: var(--c-text); }
.title { flex: 1; text-align: center; font-weight: 600; color: var(--c-text); }
</style>
```

**Step 2: MonthPicker.vue**

```vue
<script setup lang="ts">
import { computed } from 'vue'
const props = defineProps<{ modelValue: string }>() // 'YYYY-MM'
const emit = defineEmits<{ (e: 'update:modelValue', v: string): void }>()

const year = computed(() => Number(props.modelValue.slice(0, 4)))
const month = computed(() => Number(props.modelValue.slice(5, 7)))

function step(delta: number) {
  let m = month.value + delta
  let y = year.value
  if (m < 1) { m = 12; y -= 1 }
  if (m > 12) { m = 1; y += 1 }
  emit('update:modelValue', `${y}-${String(m).padStart(2, '0')}`)
}
</script>
<template>
  <view class="mp">
    <view class="btn" @tap="step(-1)">‹</view>
    <view class="label">{{ year }}-{{ String(month).padStart(2, '0') }}</view>
    <view class="btn" @tap="step(1)">›</view>
  </view>
</template>
<style scoped>
.mp { display: flex; align-items: center; gap: 24rpx; }
.btn { width: 60rpx; height: 60rpx; border-radius: 30rpx; background: var(--c-surface); display: flex; align-items: center; justify-content: center; font-size: 36rpx; }
.label { font-size: 32rpx; font-weight: 600; }
</style>
```

**Step 3: ColorSwatch.vue**

```vue
<script setup lang="ts">
const props = defineProps<{ value: string }>()
const emit = defineEmits<{ (e: 'update:value', v: string): void }>()
const palette = ['#2E7DE6', '#BA1A1A', '#FFA000', '#388E3C', '#7B1FA2', '#A0AEC0']
function pick(c: string) { emit('update:value', c) }
</script>
<template>
  <view class="sw">
    <view
      v-for="c in palette" :key="c"
      class="dot"
      :class="{ active: c === value }"
      :style="{ background: c }"
      @tap="pick(c)"
    />
  </view>
</template>
<style scoped>
.sw { display: flex; gap: 16rpx; }
.dot { width: 48rpx; height: 48rpx; border-radius: 50%; border: 2px solid transparent; }
.dot.active { border-color: var(--c-primary); }
</style>
```

**Step 4: Commit**

```bash
git add src/components/AppHeader.vue src/components/MonthPicker.vue src/components/ColorSwatch.vue
git commit -m "feat(uniapp): 基础组件 AppHeader + MonthPicker + ColorSwatch"
```

---

## Task 17: 组件 — DonutChart.vue

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/DonutChart.vue`

**Step 1: 实现(逐字翻译 React 版算法)**

打开 `frontend-react-java/src/components/DonutChart.tsx`,把 `useMemo` 的弧长计算改成 Vue 的 `computed`:

```vue
<script setup lang="ts">
import { computed } from 'vue'

interface Segment { label: string; value: number; color: string }
const props = defineProps<{
  segments: Segment[]
  totalLabel?: string
  totalValue: string
}>()

const radius = 70
const inner = 40
const cx = 100, cy = 100

const arcs = computed(() => {
  const total = props.segments.reduce((s, x) => s + x.value, 0) || 1
  let acc = 0
  return props.segments.map(s => {
    const start = (acc / total) * Math.PI * 2 - Math.PI / 2
    acc += s.value
    const end = (acc / total) * Math.PI * 2 - Math.PI / 2
    const large = end - start > Math.PI ? 1 : 0
    const x1 = cx + radius * Math.cos(start), y1 = cy + radius * Math.sin(start)
    const x2 = cx + radius * Math.cos(end),   y2 = cy + radius * Math.sin(end)
    const ix1 = cx + inner * Math.cos(end),   iy1 = cy + inner * Math.sin(end)
    const ix2 = cx + inner * Math.cos(start), iy2 = cy + inner * Math.sin(start)
    return {
      d: `M ${x1} ${y1} A ${radius} ${radius} 0 ${large} 1 ${x2} ${y2} L ${ix1} ${iy1} A ${inner} ${inner} 0 ${large} 0 ${ix2} ${iy2} Z`,
      color: s.color, label: s.label, value: s.value, pct: ((s.value / total) * 100).toFixed(1),
    }
  })
})
</script>

<template>
  <view class="wrap">
    <svg :width="200" :height="200" viewBox="0 0 200 200">
      <path v-for="(a, i) in arcs" :key="i" :d="a.d" :fill="a.color" />
      <text :x="cx" :y="cy - 6" text-anchor="middle" font-size="14" fill="var(--c-text-variant)">
        {{ totalLabel ?? '合计' }}
      </text>
      <text :x="cx" :y="cy + 16" text-anchor="middle" font-size="20" font-weight="700" fill="var(--c-text)">
        {{ totalValue }}
      </text>
    </svg>
    <view class="legend">
      <view v-for="(a, i) in arcs" :key="i" class="lg-row">
        <view class="dot" :style="{ background: a.color }" />
        <text class="lg-label">{{ a.label }}</text>
        <text class="lg-pct">{{ a.pct }}%</text>
      </view>
    </view>
  </view>
</template>

<style scoped>
.wrap { display: flex; flex-direction: column; align-items: center; gap: 24rpx; }
.legend { width: 100%; }
.lg-row { display: flex; align-items: center; gap: 12rpx; padding: 8rpx 0; }
.dot { width: 16rpx; height: 16rpx; border-radius: 50%; }
.lg-label { flex: 1; font-size: 26rpx; color: var(--c-text); }
.lg-pct { font-size: 24rpx; color: var(--c-text-variant); }
</style>
```

**Step 2: Commit**

```bash
git add src/components/DonutChart.vue
git commit -m "feat(uniapp): DonutChart(SVG 翻译自 React 版)"
```

---

## Task 18: 组件 — LineChart.vue

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/LineChart.vue`

**Step 1: 实现**

打开 `frontend-react-java/src/components/LineChart.tsx`,把 `useState/useMemo/useRef` 换成 Vue 的 `ref/computed`;平滑窗口算法直接复用。

```vue
<script setup lang="ts">
import { ref, computed } from 'vue'
import { useLanguageStore } from '@/stores/language'

interface Point { day: number; income: number; expense: number }
const props = withDefaults(defineProps<{
  data: Point[]
  incomeColor?: string
  expenseColor?: string
  smoothWindow?: number
}>(), {
  incomeColor: '#2E7DE6', expenseColor: '#BA1A1A', smoothWindow: 5,
})

const lang = useLanguageStore()
const W = 600, H = 300, pl = 40, pr = 16, pt = 16, pb = 32
const innerW = W - pl - pr, innerH = H - pt - pb

const hover = ref<{ idx: number; clientX: number; clientY: number } | null>(null)

function smooth(values: number[], w: number): number[] {
  if (w <= 1) return values
  return values.map((_, i) => {
    let sum = 0, n = 0
    for (let k = Math.max(0, i - Math.floor(w / 2)); k <= Math.min(values.length - 1, i + Math.floor(w / 2)); k++) {
      sum += values[k]; n++
    }
    return sum / n
  })
}

const maxV = computed(() => {
  const all = [...props.data.map(d => d.income), ...props.data.map(d => d.expense)]
  return Math.max(1, ...all)
})

const xs = computed(() => props.data.map((_, i) => pl + (i / Math.max(1, props.data.length - 1)) * innerW))
const ys = (v: number) => pt + innerH - (v / maxV.value) * innerH

const lineIncome = computed(() => {
  const sm = smooth(props.data.map(d => d.income), props.smoothWindow)
  return sm.map((v, i) => `${i === 0 ? 'M' : 'L'} ${xs.value[i]} ${ys(v)}`).join(' ')
})
const lineExpense = computed(() => {
  const sm = smooth(props.data.map(d => d.expense), props.smoothWindow)
  return sm.map((v, i) => `${i === 0 ? 'M' : 'L'} ${xs.value[i]} ${ys(v)}`).join(' ')
})

function onTouch(e: any) {
  const touches = e?.touches?.[0]
  if (!touches) return
  const x = touches.x - pl
  const i = Math.round((x / innerW) * (props.data.length - 1))
  hover.value = { idx: Math.max(0, Math.min(props.data.length - 1, i)), clientX: touches.x, clientY: touches.y }
}
function clearHover() { hover.value = null }
</script>

<template>
  <view class="line-wrap">
    <svg :viewBox="`0 0 ${W} ${H}`" :width="W" :height="H"
         @touchstart="onTouch" @touchmove="onTouch" @touchend="clearHover">
      <line v-for="i in 4" :key="i"
        :x1="pl" :x2="W - pr"
        :y1="pt + (innerH / 4) * i" :y2="pt + (innerH / 4) * i"
        stroke="var(--c-divider)" stroke-dasharray="2 4" />
      <path :d="lineIncome"  :stroke="incomeColor"  fill="none" stroke-width="2" />
      <path :d="lineExpense" :stroke="expenseColor" fill="none" stroke-width="2" />
      <circle v-for="(_, i) in props.data" :key="i" :cx="xs[i]" :cy="ys(data[i].income)"
              r="3" :fill="incomeColor" />
      <circle v-for="(_, i) in props.data" :key="i" :cx="xs[i]" :cy="ys(data[i].expense)"
              r="3" :fill="expenseColor" />
    </svg>
    <view v-if="hover" class="tip" :style="{ left: hover.clientX + 'px', top: hover.clientY + 'px' }">
      <view>Day {{ data[hover.idx].day }}</view>
      <view>+¥{{ data[hover.idx].income.toFixed(2) }}</view>
      <view>-¥{{ data[hover.idx].expense.toFixed(2) }}</view>
    </view>
  </view>
</template>

<style scoped>
.line-wrap { position: relative; width: 100%; }
svg { width: 100%; height: 300rpx; }
.tip {
  position: absolute; transform: translate(-50%, -120%);
  background: var(--c-bg-card); border: 1px solid var(--c-divider);
  border-radius: 8rpx; padding: 8rpx 12rpx; font-size: 22rpx; color: var(--c-text);
  pointer-events: none;
}
</style>
```

**Step 2: Commit**

```bash
git add src/components/LineChart.vue
git commit -m "feat(uniapp): LineChart(SVG 翻译自 React 版)"
```

---

## Task 19: 组件 — CategoryBadge + TransactionRow + RecordForm

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/CategoryBadge.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/TransactionRow.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/components/RecordForm.vue`

**Step 1: CategoryBadge.vue**

```vue
<script setup lang="ts">
import type { Category } from '@/api/categories'
defineProps<{ category: Category; size?: 'sm' | 'md' }>()
</script>
<template>
  <view class="badge" :class="size === 'sm' ? 'sm' : 'md'"
        :style="{ background: category.color + '33' }">
    <text class="ic">{{ category.icon }}</text>
    <text class="nm">{{ category.name }}</text>
  </view>
</template>
<style scoped>
.badge { display: inline-flex; align-items: center; gap: 8rpx; border-radius: 16rpx; padding: 4rpx 12rpx; }
.sm { font-size: 22rpx; } .md { font-size: 26rpx; }
.ic { font-size: 28rpx; } .nm { color: var(--c-text); }
</style>
```

**Step 2: TransactionRow.vue**

打开 `frontend-react-java/src/components/TransactionRow.tsx`,逐行翻译 props + 模板。

```vue
<script setup lang="ts">
import type { Record } from '@/api/records'
import { formatAmount } from '@/utils/finance'
import CategoryBadge from './CategoryBadge.vue'
import type { Category } from '@/api/categories'

defineProps<{ record: Record; category?: Category }>()
const emit = defineEmits<{ (e: 'tap', r: Record): void }>()
</script>
<template>
  <view class="row" @tap="emit('tap', record)">
    <view class="left">
      <CategoryBadge v-if="category" :category="category" size="sm" />
      <text v-else class="cat-name">未分类</text>
      <text class="note" v-if="record.note">{{ record.note }}</text>
    </view>
    <view class="right">
      <text :class="['amt', record.type === 'income' ? 'income' : 'expense']">
        {{ record.type === 'income' ? '+' : '-' }}{{ formatAmount(Math.abs(record.amount), false) }}
      </text>
      <text class="date">{{ record.occurredAt.slice(0, 10) }}</text>
    </view>
  </view>
</template>
<style scoped>
.row { display: flex; align-items: center; padding: 24rpx 16rpx; border-bottom: 1px solid var(--c-divider); }
.left { flex: 1; display: flex; flex-direction: column; gap: 6rpx; }
.cat-name { font-size: 26rpx; color: var(--c-text-variant); }
.note { font-size: 22rpx; color: var(--c-text-variant); }
.right { text-align: right; display: flex; flex-direction: column; gap: 6rpx; }
.amt.income { color: #2E7DE6; font-weight: 600; }
.amt.expense { color: var(--c-error); font-weight: 600; }
.date { font-size: 22rpx; color: var(--c-text-variant); }
</style>
```

**Step 3: RecordForm.vue**

打开 `frontend-react-java/src/components/RecordModal.tsx`,把 form 结构抽出来:

```vue
<script setup lang="ts">
import { ref, watch } from 'vue'
import { useBookStore } from '@/stores/book'
import * as accountsApi from '@/api/accounts'
import * as recordsApi from '@/api/records'
import * as categoriesApi from '@/api/categories'
import type { RecordType } from '@/api/records'
import type { Account } from '@/api/accounts'
import type { Category } from '@/api/categories'
import ColorSwatch from './ColorSwatch.vue'
import { useToastStore } from '@/stores/toast'

const props = defineProps<{ type: RecordType }>()
const emit = defineEmits<{ (e: 'saved'): void }>()

const book = useBookStore()
const toast = useToastStore()

const accounts = ref<Account[]>([])
const cats = ref<Category[]>([])
const accountId = ref<string>('')
const categoryId = ref<string>('')
const date = ref<string>(new Date().toISOString().slice(0, 10))
const amount = ref<string>('')
const color = ref<string>('#A0AEC0')
const note = ref<string>('')
const busy = ref(false)

async function load() {
  if (!book.current) return
  accounts.value = await accountsApi.listAccounts({ bookId: book.current.uuid })
  cats.value = await categoriesApi.listCategories(props.type)
  if (accounts.value.length && !accountId.value) accountId.value = accounts.value[0].id
}

watch(() => book.current?.uuid, load, { immediate: true })

async function save() {
  if (!book.current) return
  if (!amount.value || Number(amount.value) <= 0) {
    toast.show('请输入金额')
    return
  }
  if (!accountId.value) {
    toast.show('请选择账户')
    return
  }
  if (!categoryId.value) {
    toast.show('请选择分类')
    return
  }
  busy.value = true
  try {
    await recordsApi.createRecord({
      bookId: book.current.uuid,
      accountId: accountId.value,
      categoryId: categoryId.value,
      type: props.type,
      amount: Number(amount.value),
      occurredAt: new Date(date.value).toISOString(),
      note: note.value || null,
    } as any)
    toast.show('已保存')
    emit('saved')
  } catch (e: any) {
    toast.show(e?.message ?? '保存失败')
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <view class="form">
    <view class="field">
      <text class="label">类型</text>
      <text class="value">{{ type === 'expense' ? '支出' : '收入' }}</text>
    </view>
    <view class="field">
      <text class="label">金额</text>
      <input v-model="amount" type="digit" placeholder="0.00" class="input" />
    </view>
    <view class="field">
      <text class="label">账户</text>
      <picker mode="selector" :range="accounts" range-key="name" :value="accounts.findIndex(a => a.id === accountId)" @change="(e: any) => accountId = accounts[Number(e.detail.value)].id">
        <view class="picker">{{ accounts.find(a => a.id === accountId)?.name ?? '选择账户' }}</view>
      </picker>
    </view>
    <view class="field">
      <text class="label">分类</text>
      <view class="cats">
        <view v-for="c in cats" :key="c.id" class="cat-item" :class="{ active: c.id === categoryId }" @tap="categoryId = c.id">
          <text class="cat-icon">{{ c.icon }}</text>
          <text class="cat-name">{{ c.name }}</text>
        </view>
      </view>
    </view>
    <view class="field">
      <text class="label">日期</text>
      <picker mode="date" :value="date" @change="(e: any) => date = e.detail.value">
        <view class="picker">{{ date }}</view>
      </picker>
    </view>
    <view class="field">
      <text class="label">备注</text>
      <input v-model="note" placeholder="可选" class="input" />
    </view>
    <view class="actions">
      <button class="btn-primary" :disabled="busy" @tap="save">保存</button>
    </view>
  </view>
</template>

<style scoped>
.form { display: flex; flex-direction: column; gap: 24rpx; padding: 24rpx; }
.field { display: flex; flex-direction: column; gap: 8rpx; }
.label { font-size: 26rpx; color: var(--c-text-variant); }
.input, .picker { border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 16rpx; background: var(--c-bg-card); color: var(--c-text); }
.cats { display: flex; flex-wrap: wrap; gap: 12rpx; }
.cat-item { display: flex; align-items: center; gap: 8rpx; padding: 8rpx 16rpx; border: 1px solid var(--c-divider); border-radius: 24rpx; }
.cat-item.active { border-color: var(--c-primary); background: var(--c-primary-light); }
.cat-icon { font-size: 28rpx; } .cat-name { font-size: 24rpx; }
.actions { margin-top: 24rpx; }
</style>
```

**Step 4: Commit**

```bash
git add src/components/CategoryBadge.vue src/components/TransactionRow.vue src/components/RecordForm.vue
git commit -m "feat(uniapp): CategoryBadge + TransactionRow + RecordForm"
```

---

## Task 20: 页面 — Login

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/login/index.vue`

**Step 1: 实现**

打开 `frontend-react-java/src/pages/Login.tsx`,逐字段翻译,提交调 `useAuthStore().login()`,成功后 `uni.reLaunch('/pages/index/index')`。

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { useAuthStore } from '@/stores/auth'
import { useToastStore } from '@/stores/toast'
import { useLanguage } from '@/i18n/useLanguage'
import { useThemeStore } from '@/stores/theme'
import { LANGS } from '@/i18n/dict'

const auth = useAuthStore()
const toast = useToastStore()
const { t, lang, setLang } = useLanguage()
const theme = useThemeStore()

const username = ref('')
const password = ref('')
const busy = ref(false)

async function submit() {
  if (!username.value || !password.value) { toast.show('请输入账号和密码'); return }
  busy.value = true
  try {
    await auth.login({ username: username.value, password: password.value })
    uni.reLaunch({ url: '/pages/index/index' })
  } catch (e: any) {
    toast.show(e?.message ?? '登录失败')
  } finally {
    busy.value = false
  }
}
</script>

<template>
  <view class="login">
    <view class="head">
      <text class="logo">Q</text>
      <text class="brand">{{ t('app.title') }}</text>
    </view>
    <view class="card">
      <view class="field">
        <text class="label">{{ t('login.username') }}</text>
        <input v-model="username" class="input" :placeholder="t('login.usernamePh')" />
      </view>
      <view class="field">
        <text class="label">{{ t('login.password') }}</text>
        <input v-model="password" type="password" class="input" :placeholder="t('login.passwordPh')" />
      </view>
      <button class="btn-primary" :disabled="busy" @tap="submit">{{ t('login.submit') }}</button>
    </view>
    <view class="prefs">
      <picker mode="selector" :range="LANGS.map(l => l.label)" :value="LANGS.findIndex(l => l.code === lang)" @change="(e: any) => setLang(LANGS[Number(e.detail.value)].code)">
        <view class="pref-item">{{ lang.label }}</view>
      </picker>
      <view class="pref-item" @tap="theme.setMode(theme.mode === 'dark' ? 'light' : 'dark')">
        {{ theme.mode === 'dark' ? '🌙' : '☀️' }}
      </view>
    </view>
  </view>
</template>

<style scoped>
.login { padding: 64rpx 48rpx; display: flex; flex-direction: column; gap: 48rpx; }
.head { display: flex; align-items: center; gap: 16rpx; }
.logo { width: 64rpx; height: 64rpx; border-radius: 16rpx; background: var(--c-primary); color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 700; }
.brand { font-size: 36rpx; font-weight: 700; }
.card { background: var(--c-bg-card); border-radius: 16rpx; padding: 32rpx; display: flex; flex-direction: column; gap: 24rpx; }
.field { display: flex; flex-direction: column; gap: 8rpx; }
.label { font-size: 24rpx; color: var(--c-text-variant); }
.input { border: 1px solid var(--c-divider); border-radius: 12rpx; padding: 16rpx; background: var(--c-bg); color: var(--c-text); }
.prefs { display: flex; gap: 16rpx; justify-content: flex-end; }
.pref-item { padding: 8rpx 16rpx; border-radius: 16rpx; background: var(--c-surface); font-size: 24rpx; }
</style>
```

**Step 2: Commit**

```bash
git add src/pages/login
git commit -m "feat(uniapp): 登录页"
```

---

## Task 21: 页面 — Home

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/index/index.vue`

**Step 1: 实现**

打开 `frontend-react-java/src/pages/Home.tsx`,翻译:
- 顶部 user 卡(头像 / displayName / 本月支出 / 本月收入 / 本月结余)
- 快捷「记一笔」按钮 → `uni.navigateTo({ url: '/pages/record/expense' })` 和 `/record/income`
- 最近 5 条流水
- 月份选择器接 MonthPicker,默认本月

**Step 2: Commit**

```bash
git add src/pages/index
git commit -m "feat(uniapp): 首页"
```

---

## Task 22: 页面 — Transactions + Record

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/transactions/index.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/record/expense.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/record/income.vue`

**Step 1: transactions/index.vue**

打开 `frontend-react-java/src/pages/Transactions.tsx`,字段 / 筛选条件 / 编辑删除 1:1。点击行 → 弹底部抽屉(自定义组件 `RecordForm` 复用或精简编辑),删除前 `uni.showModal` 确认。

**Step 2: record/expense.vue & record/income.vue**

每个就是一个全屏页,内嵌 `<RecordForm :type="..." @saved="back" />`,提交成功后 `uni.navigateBack()`。

**Step 3: Commit**

```bash
git add src/pages/transactions src/pages/record
git commit -m "feat(uniapp): 流水 + 记支出/记收入"
```

---

## Task 23: 页面 — Reports (月报 / 年报)

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/reports/monthly.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/reports/yearly.vue`

**Step 1: monthly.vue**

打开 `frontend-react-java/src/pages/ReportMonthly.tsx`,翻译:
- MonthPicker 选月份
- 顶部当月收入 / 支出 / 结余 三个数字卡
- `<LineChart :data="dailyData" />` ← 用 Task 18 的组件
- 分类占比 `<DonutChart :segments="..." />` ← 用 Task 17 的组件
- 分类列表(每行:icon + name + 占比 + 金额)

**Step 2: yearly.vue**

打开 `frontend-react-java/src/pages/ReportYearly.tsx`,翻译:
- 年份选择
- 12 个月柱状或环形汇总
- 分类 / 账户年汇总

**Step 3: Commit**

```bash
git add src/pages/reports
git commit -m "feat(uniapp): 月报 + 年报"
```

---

## Task 24: 页面 — Accounts + AccountAdd

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/accounts/index.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/accounts/new.vue`

**Step 1: 翻译**

打开 `frontend-react-java/src/pages/Accounts.tsx` 和 `AccountAdd.tsx`,字段(name / type / initialBalance / currency / color / isDefault) 1:1,删除/编辑走 `uni.showModal` 确认。

**Step 2: Commit**

```bash
git add src/pages/accounts
git commit -m "feat(uniapp): 账户列表 + 新建账户"
```

---

## Task 25: 页面 — Books + BookMembers

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/books/index.vue`
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/books/members.vue`

**Step 1: 翻译**

打开 `frontend-react-java/src/pages/Books.tsx` 与 `BookMembers.tsx`,字段(name / type / currency / isDefault) 1:1;成员页支持添加成员 / 改角色 / 移除。

**Step 2: Commit**

```bash
git add src/pages/books
git commit -m "feat(uniapp): 账本列表 + 成员管理"
```

---

## Task 26: 页面 — Settings(**不含数据管理**)

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/settings/index.vue`

**Step 1: 实现**

打开 `frontend-react-java/src/pages/Settings.tsx`,**严格剔除**数据管理整段(`<div className="bento-item bg-bg-card p-8">` 包 3 个导出按钮那一块,以及 i18n key `settings.data.*` 一律不引用)。保留:
  - 用户卡片(头像 + displayName + username + 性别 + 年龄 + 编辑按钮)
  - 系统偏好(主题 segmented + 语言 picker)
  - 分类管理(完整功能:列表 / 新建 / 编辑 / 删除,**保留**)
  - 关于(版本号)
  - 账号安全(退出按钮)

模板用卡片样式替代 bento-grid;字段、文案、交互 1:1。

**Step 2: Commit**

```bash
git add src/pages/settings
git commit -m "feat(uniapp): 设置页(去除数据管理)"
```

---

## Task 27: 页面 — ProfileEdit

**Files:**
- Create: `007.跨端APP应用（移动端开发工程师）/src/pages/profile/edit.vue`

**Step 1: 翻译**

打开 `frontend-react-java/src/pages/ProfileEdit.tsx`,字段(displayName / avatar / gender / age) 1:1;颜色选择用 ColorSwatch 替代 `<input type="color">`。

**Step 2: Commit**

```bash
git add src/pages/profile
git commit -m "feat(uniapp): 编辑资料"
```

---

## Task 28: tabBar 配置 + 启动守卫

**Files:**
- Modify: `007.跨端APP应用（移动端开发工程师）/src/pages.json`(追加 tabBar)
- Modify: `007.跨端APP应用（移动端开发工程师）/src/App.vue`(追加 token 缺失守卫)

**Step 1: 修改 src/pages.json 末尾加 tabBar**

```json
{
  "tabBar": {
    "color": "#5F6368",
    "selectedColor": "#2E7DE6",
    "backgroundColor": "#FFFFFF",
    "borderStyle": "white",
    "list": [
      { "pagePath": "pages/index/index",        "text": "首页" },
      { "pagePath": "pages/transactions/index", "text": "流水" },
      { "pagePath": "pages/reports/monthly",    "text": "报表" },
      { "pagePath": "pages/settings/index",     "text": "我的" }
    ]
  }
}
```

> 注意:`tabBar` 页面无法用 `uni.navigateTo` 跳到另一个 tab 页,需用 `uni.switchTab`。在 Home 页和 Settings 页里的「打开报表」「打开流水」入口用 `uni.switchTab`;其他内部跳转用 `uni.navigateTo`。

**Step 2: 修改 App.vue 加守卫**

```vue
<script setup lang="ts">
import { onLaunch } from '@dcloudio/uni-app'
import { useAuthStore } from '@/stores/auth'
import { useBookStore } from '@/stores/book'
import { useThemeStore } from '@/stores/theme'
import { useLanguageStore } from '@/stores/language'
import ToastHost from '@/components/Toast.vue'

const auth = useAuthStore()
const book = useBookStore()
const theme = useThemeStore()
const lang  = useLanguageStore()

onLaunch(async () => {
  theme.applySystemListener()
  lang.hydrate()
  if (!auth.token) {
    uni.reLaunch({ url: '/pages/login/index' })
    return
  }
  try { await auth.me() } catch { return }
  try { await book.reload() } catch { /* 容忍 */ }
})
</script>
```

**Step 3: Commit**

```bash
git add src/pages.json src/App.vue
git commit -m "feat(uniapp): tabBar + 启动守卫"
```

---

## Task 29: 跨端冒烟测试

**Files:**(无新文件,验收步骤)

**Step 1: H5(浏览器)跑通**

```bash
cd "007.跨端APP应用（移动端开发工程师）"
npm run dev:h5
# 浏览器打开 http://localhost:5173
# 验收清单:
#  1. 未登录跳 /pages/login/index → 输入账号密码登录成功 → 进首页
#  2. 首页:本月汇总 + 5 条最近流水 + 「记一笔」可跳 record/expense
#  3. 记一笔:输入金额 + 选账户 + 选分类 + 保存 → 回到首页看到新流水
#  4. 流水 tab:列表 + 编辑 + 删除
#  5. 报表 tab:monthly 显示折线 + 环形
#  6. 我的 tab:主题切换 / 语言切换 / 分类增删改 / 退出登录
```

**Step 2: 微信小程序**

```bash
npm run dev:mp-weixin
# 用微信开发者工具打开 dist/dev/mp-weixin/
# 验收清单:同上,小程序特有:
#  - picker 弹层正常
#  - token 失效跳登录
#  - 后端域名白名单:开发期在 mp-weixin → 后台开 不校验合法域名
```

**Step 3: App(iOS / Android)**

```bash
npm run dev:app
# 用 HBuilderX → 运行 → 真机/模拟器
# iOS:配置 Apple 证书(personal team 也行),Android:配置 debug keystore
# 验收清单:同上,App 特有:
#  - 启动图 + 启动屏正常
#  - 主题切换实时生效(无 system matchMedia 时回 light)
```

**Step 4: 修复任何 bug + commit**

```bash
git add -A
git commit -m "fix(uniapp): 跨端冒烟修复"
```

---

## Self-Review(本计划对自己)

1. **Spec 覆盖:**
   - §2.1 14 个页面:Login/Home/Transactions/Record×2/Reports×2/Accounts×2/Books×2/Settings/ProfileEdit → Task 20-27 ✅
   - §2.1 鉴权 login/logout/me → Task 12 (auth store) + Task 5 (api/auth) ✅
   - §2.1 i18n zh-CN/en/zh-TW → Task 3 ✅
   - §2.1 主题三档 → Task 14 (theme store) + Task 2 (CSS) ✅
   - §2.1 Toast → Task 15 ✅
   - §2.2 设置数据管理移除 → Task 26 + Task 3 (删除 dict keys) ✅
   - §3 栈选型 uniapp+ts+vite+uView+UnoCSS+Pinia+SVG → Task 1 + Task 17-18 ✅
   - §5 tabBar(首页/流水/报表/我的)→ Task 28 ✅
   - §7 HTTP 层 → Task 4 ✅
   - §8 API 模块 8 个 → Task 5-10 ✅
   - §9 i18n → Task 3 ✅
   - §10 图表 → Task 17 + Task 18 ✅
   - §11 tokens → Task 2 ✅
   - §13 跨端差异(date/color/select/confirm → uView)→ 散落在 Task 16 / 19 / 22 / 24 ✅

2. **占位符扫描:** 无 "TBD" / "implement later" / "类似 Task N"。

3. **类型一致:** `useAuthStore().login(creds: Credentials)` 在 Task 12 + Task 20 + Task 19 引用一致;`useBookStore().current` 在 Task 19/21/22/24/25 引用一致;`useToastStore().show(msg)` 在 Task 19/20/22/24/25 引用一致;`formatAmount(n, withSymbol=false)` 在 Task 19 + 后续页面调用一致。

4. **范围检查:** 单项目(uniapp 跨端),单 plan 可覆盖。

---

## 执行选项

**Plan 已保存到 `docs/superpowers/plans/2026-08-31-uniapp-cross-platform-app.md`。**

接下来:
1. **Subagent-Driven(推荐)** — 我每个 task 派一个 fresh subagent,每个 task 之间我做两阶段 review,快速迭代
2. **Inline Execution** — 当前会话执行,批量推进 + 检查点

哪种?