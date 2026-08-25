# 轻账 · 前端原型站点

> 纯静态多页面原型，用于展示「轻账」App 的 12 个核心界面与跳转关系。

## 项目说明

本目录（`003.前端代码/frontend`）存放轻账的高保真 HTML 原型，基于：

- [`001.产品PRD/轻账-产品需求文档PRD.md`](../001.产品PRD/轻账-产品需求文档PRD.md)
- [`001.产品PRD/轻账-产品需求文档PRD-V1.0.1.md`](../001.产品PRD/轻账-产品需求文档PRD-V1.0.1.md)
- [`docs/DESIGN.md`](./docs/DESIGN.md)

原型使用 Tailwind CSS（CDN）、Google Fonts / Material Symbols（CDN）和 Chart.js（CDN）构建，**无需任何构建工具**，双击 `index.html` 即可在浏览器中预览。

## 目录结构

```
003.前端代码/
└── frontend/
    ├── index.html              # 导航预览入口
    ├── README.md               # 本文件
    ├── pages/                  # 12 个语义化命名页面
    │   ├── 01-login.html
    │   ├── 02-register.html
    │   ├── 03-home.html
    │   ├── 04-transactions.html
    │   ├── 05-record-expense.html
    │   ├── 06-record-income.html
    │   ├── 07-report-monthly.html
    │   ├── 08-report-yearly.html
    │   ├── 09-accounts.html
    │   ├── 10-account-add.html
    │   ├── 11-settings.html
    │   └── 12-profile-edit.html
    ├── screenshots/            # 每页对应的原型截图
    │   ├── 01-login.png
    │   └── ...
    └── docs/
        └── DESIGN.md           # 设计系统 / Design Tokens
```

## 页面清单

| 编号 | 页面 | 功能 |
|------|------|------|
| 01 | [登录](./pages/01-login.html) | 用户名 + 密码登录 |
| 02 | [注册](./pages/02-register.html) | 用户名 + 密码注册 |
| 03 | [首页](./pages/03-home.html) | 仪表盘、收支概览、本月预算 |
| 04 | [全部交易](./pages/04-transactions.html) | 交易列表、筛选、搜索 |
| 05 | [记一笔-支出](./pages/05-record-expense.html) | 支出记账面板 |
| 06 | [记一笔-收入](./pages/06-record-income.html) | 收入记账面板 |
| 07 | [月度报表](./pages/07-report-monthly.html) | 月度收支统计 |
| 08 | [年度报表](./pages/08-report-yearly.html) | 年度收支统计 |
| 09 | [账户管理](./pages/09-accounts.html) | 账户列表与余额 |
| 10 | [添加账户](./pages/10-account-add.html) | 新增账户表单 |
| 11 | [设置](./pages/11-settings.html) | 通用设置入口 |
| 12 | [编辑资料](./pages/12-profile-edit.html) | 用户资料编辑 |

## 跳转关系

```
登录 (01) ──注册/登录──▶ 首页 (03)

首页 (03)
    ├── 全部交易 (04)
    ├── 记一笔-支出 (05) ◀──▶ 记一笔-收入 (06)
    ├── 月度报表 (07) ◀──▶ 年度报表 (08)
    ├── 账户管理 (09) ──▶ 添加账户 (10)
    └── 设置 (11) ──▶ 编辑资料 (12)

设置 (11) ──退出登录──▶ 登录 (01)
```

### 核心交互

- **登录页**：点击「登录」进入首页；点击「注册」Tab 切换到注册页。
- **注册页**：点击「注册」进入首页；点击「登录」Tab 切换到登录页。
- **首页 FAB**：点击右下角「+」进入记一笔-支出页。
- **记一笔页**：顶部 Tab 可在「支出」与「收入」间切换；右上角「×」关闭回到首页；右下角「✓」完成回到首页。
- **报表页**：月度报表与年度报表可相互切换。
- **账户页**：点击「添加账户」进入添加账户表单。
- **添加账户**：左上角返回、取消、保存均回到账户管理页。
- **设置页**：「编辑资料」进入编辑页；「退出登录」回到登录页。
- **编辑资料**：左上角返回回到设置页。

## 如何运行

### 方式一：直接打开（推荐）

双击 `frontend/index.html` 即可。浏览器中打开导航页，点击任意卡片进入对应原型页面。

### 方式二：本地 HTTP 服务器

某些浏览器对 `file://` 协议下加载图片或字体有安全限制，可启动本地服务器：

```bash
cd 003.前端代码/frontend
python3 -m http.server 8080
```

然后访问：http://localhost:8080

## 技术说明

- **无构建工具**：仅使用 CDN 资源，无 Vite / Webpack / React 依赖。
- **无后端依赖**：登录/注册/记账均为原型跳转，数据不做真实提交。
- **响应式布局**：基于 Tailwind CSS 的移动端优先布局，桌面端以 375px 宽度居中模拟手机视图。
- **设计系统**：颜色、间距、圆角、字号等 Token 见 [`docs/DESIGN.md`](./docs/DESIGN.md)。

## 与 PRD 的对应关系

| PRD 功能模块 | 对应页面 |
|--------------|----------|
| 用户登录 | 01-login |
| 用户注册（v1.0.1） | 02-register |
| 首页仪表盘 | 03-home |
| 交易记录 | 04-transactions |
| 快速记账 | 05-record-expense / 06-record-income |
| 报表分析 | 07-report-monthly / 08-report-yearly |
| 账户管理 | 09-accounts / 10-account-add |
| 设置与个人中心 | 11-settings / 12-profile-edit |

## 维护提示

- 新增页面时按 `NN-semantic-name.html` 命名，并在 `index.html` 和本 README 的页面清单中同步。
- 页面间跳转统一使用同级相对路径 `./NN-name.html`。
- 截图保持与页面同名，存放到 `screenshots/` 目录。
