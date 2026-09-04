# 007 iOS 真机 E2E 检查清单(占位骨架)

> 不在 vitest 自动化范围内,本目录列出真机 + 平台特定场景,QA 跑测时勾选。

## QuickAddModal iOS 修复回归(高优先级)
- [ ] iPhone 12 (iOS 16) — 点快速记账 → modal 弹出,无 `parentNode null` / `_vei` / `setAttribute null` 报错
- [ ] iPhone 15 (iOS 17/18) — 同上
- [ ] iPad (iPadOS 16/17) — 同上,横屏旋转测试

## 平台差异测试
- [ ] H5 (Chrome desktop) — 弹框 OK
- [ ] H5 (iOS Safari 17) — 弹框 OK
- [ ] H5 (Android Chrome) — 弹框 OK
- [ ] mp-weixin (开发者工具) — 弹框 OK
- [ ] mp-weixin (真机) — 弹框 OK

## UI 安全区
- [ ] iOS 模态打开 → 顶部 Dynamic Island 窄带 navy(theme-color 切换)
- [ ] iOS 模态打开 → UIWindow bg 改 navy(`qa-window-bg` 生效)
- [ ] H5 模态打开 → html/body bg navy(无白边)
- [ ] mp 模态打开 → 原生导航栏让位

## 滚动 + tabBar
- [ ] H5 iPhone — 滚到底不被 tabBar 盖
- [ ] H5 横屏 → tabbar height 自动重测
- [ ] iOS — 模态打开 → uni.hideTabBar() 生效

## 数据一致性(同笔记账)
- [ ] 三平台同 user 登录,创建账户 → 余额一致
- [ ] 三平台创建同一笔记 → 流水列表一致

## URLSearchParams polyfill
- [ ] mp 模拟器(老基础库版本)→ URLSearchParams 不存在 → polyfill 兜底生效,页面不白

## vConsole
- [ ] H5 dev — 屏幕右下角 vConsole 浮窗可见
- [ ] H5 生产打包前移除 vConsole(手动注释 main.js)

---

**说明**:此清单由 QA 在真机上勾选,完成后拍照归档到
`008.项目测试（测试工程师）/测试报告/007-uniapp-project/platforms/`。