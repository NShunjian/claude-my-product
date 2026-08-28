# 轻账 E2E 验证脚本

> **状态(2026-08-28)**：Phase B 整条链路(注册 → 快速记账 → 月报/年报/账户/流水/编辑资料/添加账户)的可视证据。
> 脚本和本 README 同在 `frontend-react/e2e/` 下,可直接 CI 接入:
> ```
> frontend-react/e2e/
> ├── README.md          ← 本文件
> ├── run.py             ← Playwright 脚本(已搬入)
> └── screenshots/       ← 截图输出(已在根 .gitignore 排除,不入仓)
> ```
> 旧位置 `/tmp/qz-e2e/` 可保留作调试备份;CI 一律从仓库内跑。

---

## 1. 跑什么

注册新用户 → 通过 API 拿到 JWT → 注入到浏览器 localStorage → 模拟用户点击"快速记账"两次(支出 ¥35.50 / 收入 ¥5,000.00)→ 访问所有 11 个业务页面并截图。

**覆盖的页面**(共 13 张截图):

| # | 文件 | 关键场景 |
|---|------|---------|
| 01 | `01-home-fresh.png` | 注册后空首页(5 个默认账户已建好) |
| 02 | `02-record-expense-empty.png` | 支出记账页初始态 |
| 03 | `03-record-expense-filled.png` | 餐饮 / 微信支付 / ¥35.50 填好,等待点 √ |
| 04 | `04-home-after-expense.png` | 记完支出回到首页 |
| 05 | `05-record-income-empty.png` | 收入记账页初始态 |
| 06 | `06-record-income-filled.png` | 工资 / 银行卡 / ¥5,000 填好,等待点 √ |
| 07 | `07-home-after-income.png` | 记完两笔后首页最终态(KPI / 最近交易 / 分类排行) |
| 08 | `08-report-monthly.png` | 月报(总支出 / 总收入 / 分类饼图 / 每日趋势) |
| 09 | `09-report-yearly.png` | 年报 |
| 10 | `10-accounts.png` | 账户管理 |
| 11 | `11-transactions.png` | 全部交易流水 |
| 12 | `12-profile-edit.png` | 编辑资料 |
| 13 | `13-account-add.png` | 添加账户页 |

数据校验闭环(以 `e2e_<timestamp>` 新用户为例):
- 记 35.50 餐饮/微信支付 → 微信支付账户余额 -35.50
- 记 5000 工资/银行卡 → 银行卡账户余额 +5000
- 首页/流水/报表/账户 四端数据一致
- 月报每日趋势曲线在 27 号(执行日)正确跳升

---

## 2. 前提

| 依赖 | 版本/状态 |
|------|---------|
| Python | 3.10+ |
| Playwright Python | 已装;`python3 -c "from playwright.sync_api import sync_playwright; print('ok')"` |
| Chromium | 已下载(playwright install) |
| 后端 dev server | `http://localhost:4000` 在跑 |
| 前端 dev server | `http://localhost:5173` 在跑 |
| MySQL | `qingzhang` 库可达(后端启动会自动连接) |

后端/前端启动命令:
```bash
# 后端
cd "003.前端代码（前端工程师）/backend"
npm run dev          # tsx watch on :4000

# 前端(另开终端)
cd "003.前端代码（前端工程师）/frontend-react"
npm run dev          # vite on :5173
```

---

## 3. 怎么跑

```bash
# 从仓库根目录
python3 "003.前端代码（前端工程师）/frontend-react/e2e/run.py"

# 或 cd 进 e2e/ 直接跑
cd "003.前端代码（前端工程师）/frontend-react/e2e"
python3 run.py
```

输出:
- `[setup] registered e2e_<timestamp>, token len=239`
- `[shot] /tmp/qz-e2e/01-home-fresh.png  size=...`
- ... 13 张
- `[done] e2e_<timestamp>  all screenshots in /tmp/qz-e2e`

每次跑注册一个**新用户**(`e2e_<unix_timestamp>`),不污染已有数据,无清理负担。

---

## 4. 关键选择器(改 UI 后要更新)

`run.py` 用 `page.get_by_role / get_by_text / locator` 三种方式:

| UI 元素 | 选择器 | 来源 |
|---------|--------|------|
| 注册/登录 切换 | 顶部 `登录` / `注册` tab text | `pages/Login.tsx` |
| 用户名/密码输入 | `input#username` / `input#password` | 同上 |
| 提交按钮 | text = `登录` / `注册` | 同上 |
| 分类按钮 | `get_by_role('button', name='餐饮')` | `components/RecordModal.tsx:307` |
| 账户按钮 | `locator('button').filter(has_text='微信支付')` | `RecordModal.tsx:359` |
| 数字键 | `get_by_role('button', name='3', exact=True)` | `RecordModal.tsx:469` |
| 小数点 | `locator('button').filter(has_text='.')` | 同上 |
| 保存按钮(√) | `button:has(.material-symbols-outlined) >> has(.material-symbols-outlined:has-text('check'))` | `RecordModal.tsx:413-431` |
| 备注 | `placeholder='添加备注...'` | `RecordModal.tsx:395` |
| 页面就绪 | `wait_for_selector('text=<该页 page title>')` | 各页 `usePageTitle` |

> 改了 UI 后,优先看 `RecordModal.tsx`(选分类/账户/数字键盘/√按钮都在这里)。

---

## 5. 怎么扩展

### 5.1 加新场景(比如转账)

在 `run.py` 加:
```python
# 5) 记一笔 transfer(目前 transfer 路由需要走 RecordExpense 不支持,直接走 API)
req = urllib.request.Request(
    "http://localhost:4000/api/records",
    data=json.dumps({
        "type": "transfer",
        "accountId": "wechat-uuid",  # 真实 UUID
        "toAccountId": "bank-uuid",
        "amount": 100,
        "recordDate": "2026-08-27",
    }).encode(),
    headers={"Content-Type": "application/json", "Authorization": f"Bearer {TOKEN}"},
    method="POST",
)
urllib.request.urlopen(req, timeout=10).read()
```

### 5.2 加新页面截图

```python
# 截图清单后追加
page.goto("http://localhost:5173/<new-page>")
page.wait_for_load_state("networkidle")
page.wait_for_selector("text=<该页标题>", timeout=10000)
time.sleep(0.5)  # 让动画/loading 稳定
shot(page, "14-new-page.png")
```

### 5.3 改用户名/密码

`run.py` 顶部:
```python
USERNAME = f"e2e_{int(time.time())}"
PASSWORD = "demo1234"
```

### 5.4 改视口大小

`ctx = browser.new_context(viewport={"width": 1920, "height": 1080}, ...)` — 视口大更接近桌面,小更接近手机。

### 5.5 调试

- 改 `headless=False` 看浏览器实际行为
- 加 `page.pause()` 在关键步骤
- `page.screenshot(path='/tmp/debug.png')` 任何位置插一张

---

## 6. CI 接入思路(暂未实装)

最小可行方案:
1. **搬脚本进 git**:`mv /tmp/qz-e2e/run.py frontend-react/e2e/run.py`,README 同目录
2. **截图不入仓**:`.gitignore` 加 `frontend-react/e2e/screenshots/`
3. **CI 步骤**:
   - 启动后端 + 前端(后台)
   - 等待 `curl http://localhost:4000/api/categories` 返 200
   - 等待 `curl http://localhost:5173/` 返 200
   - 跑 `python3 e2e/run.py`,断言 `len(glob('e2e/screenshots/*.png')) == 13`
   - 上传截图作为 CI artifact(GitHub Actions `actions/upload-artifact`)
4. **失败处理**:Playwright 默认 30s timeout,关键步骤可加 `expect` 断言(`pip install playwright-assertions` 或手写 `assert page.locator(...).is_visible()`)
5. **替代品**:
   - **Playwright JS/TS**:`@playwright/test` + `npx playwright test` 跟现有 vitest 风格一致(不用 Python)
   - **Cypress**:组件测试友好,但需 Node 集成度更高
   - 当前 Python 实现的优点:**零前端构建依赖**,纯 HTTP + 浏览器

---

## 7. 已知限制

- **未测 transfer UI**:前端 RecordModal 当前只有 expense/income,transfer 走 API
- **未测编辑资料保存**:只截图页面,没填值
- **未测响应式**:固定 1440x900,需要再加手机视口
- **未测离线 / 弱网**:Playwright 默认网络通畅
- **无失败重试**:某步失败直接退出(返回非 0 exit code),可加 `tenacity` 重试

---

## 8. 相关文件

| 路径 | 作用 |
|------|------|
| `/tmp/qz-e2e/run.py` | 当前脚本(临时,建议搬进 e2e/) |
| `/tmp/qz-e2e/*.png` | 13 张截图(临时) |
| `frontend-react/src/components/RecordModal.tsx` | UI 选择器主要来源 |
| `frontend-react/src/pages/Login.tsx` | 登录/注册 UI |
| `backend/src/routes/*.routes.ts` | API 路径(脚本通过 `urllib` 直接调) |
