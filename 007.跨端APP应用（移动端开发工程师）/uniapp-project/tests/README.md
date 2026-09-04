# 007 uniapp-project — tests/ 目录说明

> 新增目录,不动 src/、manifest.json、App.vue、pages.json、uni_modules/。
> 仅测**纯逻辑 + 可在 Node / happy-dom 跑的部分**;真机平台特定场景留 platforms/ 清单。

## 目录结构

```
uniapp-project/
├── src/                                业务代码(不动)
├── pages.json / manifest.json          uni-app 配置(不动)
├── App.vue / main.js                   应用入口(不动)
├── uni_modules/qa-window-bg/           iOS 原生插件(不动)
└── tests/                              新增
    ├── README.md                       本文件
    ├── setup.ts                        vitest 全局 setup(屏蔽 uni.* API)
    ├── unit/                           纯函数 / 工具 单测
    │   ├── finance.test.ts             utils/finance.ts
    │   ├── category-presentation.test.ts utils/category-presentation.ts
    │   └── nav-intent.test.ts          utils/nav-intent.ts(跨页意图传参)
    ├── stores/                         Pinia store 状态机测试
    │   └── quick-add.test.ts           stores/quick-add.ts
    ├── platforms/                      平台特定(留作真机冒烟清单)
    │   └── ios-modal.md                iOS QuickAddModal 修复回归清单
    ├── playwright-report/              本地 playwright 输出(不进 git)
    ├── coverage/                       本地 coverage 输出(不进 git)
    └── scripts/
        └── copy-report.mjs             同步到 008.项目测试/测试报告/007-uniapp-project/
```

## 命令

```bash
# H5 dev(已有,不动)
npm run dev:h5             # http://localhost:5181

# 测试(新增,需先 npm install)
npm run test               # vitest run
npm run test:watch         # vitest
npm run test:unit          # 只跑 tests/unit/
npm run test:stores        # 只跑 tests/stores/
npm run test:coverage      # vitest run --coverage
npm run test:report        # test:coverage + 拷贝到 008.项目测试/测试报告/007-uniapp-project/

# 真机
# HBuilderX 自定义基座 + iPhone 真机 → 跑 platforms/ios-modal.md 清单
# 微信开发者工具 → 跑模拟器冒烟
```

## 报告输出

- **vitest coverage**(HTML + lcov):`tests/coverage/` + 同步到
  `../../008.项目测试（测试工程师）/测试报告/007-uniapp-project/coverage/`
- **Playwright E2E**(HTML):`tests/playwright-report/` + 同步到
  `../../008.项目测试（测试工程师）/测试报告/007-uniapp-project/e2e/`
- **平台清单**(勾选结果):`tests/platforms/` 同步到
  `../../008.项目测试（测试工程师）/测试报告/007-uniapp-project/platforms/`

## 当前状态

- vitest 骨架就位(setup + 4 个 spec + 配置 + copy 脚本)
- 平台特定测试以 markdown 清单形式提供(`platforms/ios-modal.md`),留给真机 QA 跑

## 新增依赖(需 `npm install`)

- `vitest` + `@vitest/ui`
- `happy-dom`(Vue SFC 渲染)
- `@vue/test-utils`
- `pinia`(已是 prod 依赖,无需新增)
- `@playwright/test`(可选)

依赖已写入 package.json `devDependencies`。

## 关键约定

1. **测试账号**:`uniaptest1` / `UniappTest@12345`,不复用已有真实账号。
2. **不动 src/** + **不动 uni_modules/**:测试只对 utils/ + stores/ + 部分可独立组件。
3. **平台特定不在 vitest 范围**:QuickAddModal iOS 直接渲染分支、tabBar 控制、原生插件
   调试 — 全部走真机 + platforms/ 清单。
4. **CORS**:本项目 H5 dev 端口 = **5181**(非 5173),后端 `CorsConfig` 必须含此端口
   ([uniapp H5 dev 端口是 5181] 项目约束)。
5. **mp SVG 走 data URI image**([uniapp mp SVG 走 data URI image]):视觉测试时 SVG 应嵌 data URI。

## 不在 vitest 范围(留给真机)

- `<QuickAddModal>` 完整渲染(包含 `<!-- #ifdef H5 || APP-PLUS -->` 分支)
- `<App>` 路由 + tabBar + 暗色主题
- 原生插件 `qa-window-bg`(`utssdk/app-ios/index.uts`)
- xlsx 导出(uniapp 平台差异大)