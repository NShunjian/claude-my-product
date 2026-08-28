"""轻账 E2E 验证：注册 → 快速记账(支出+收入) → 首页/报表/账户/编辑资料 截图。

服务器已在跑：
  - http://localhost:4000  后端（Express 5 + MySQL）
  - http://localhost:5173  前端（Vite + React 19）

本脚本只负责浏览器操作 + 截图，不启动 dev server。

跑法：
  cd frontend-react/e2e
  python3 run.py

截图输出到 ./screenshots/（已在 .gitignore 中排除，体积大不入仓）。
CI 集成：把 screenshots 作为 artifact 上传即可。
"""
import json
import time
import urllib.request
from pathlib import Path
from playwright.sync_api import sync_playwright

# 截图输出目录：脚本同级的 screenshots/ 子目录
OUT = Path(__file__).resolve().parent / "screenshots"
OUT.mkdir(parents=True, exist_ok=True)


def register_via_api(username: str, password: str) -> str:
    req = urllib.request.Request(
        "http://localhost:4000/api/auth/register",
        data=json.dumps({"username": username, "password": password}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())["token"]


USERNAME = f"e2e_{int(time.time())}"
PASSWORD = "demo1234"
TOKEN = register_via_api(USERNAME, PASSWORD)
print(f"[setup] registered {USERNAME}, token len={len(TOKEN)}")


def shot(page, name: str):
    p = OUT / name
    page.screenshot(path=str(p), full_page=True)
    print(f"[shot] {p}  size={p.stat().st_size}")


def press_digits(page, s: str):
    """按数字键盘输入金额(每键精确匹配)"""
    for ch in s:
        if ch == '.':
            # 小数点按钮 — 模态框里是 button 文本恰好为 "."
            page.locator('button').filter(has_text=ch).first.click()
        else:
            page.get_by_role("button", name=ch, exact=True).click()
        time.sleep(0.06)


def confirm(page):
    """点右下角 √ 保存按钮(含 material symbol 'check')"""
    page.locator('button:has(.material-symbols-outlined)').filter(
        has=page.locator('.material-symbols-outlined', has_text="check")
    ).first.click()


with sync_playwright() as pw:
    browser = pw.chromium.launch(headless=True)
    ctx = browser.new_context(
        viewport={"width": 1440, "height": 900},
        locale="zh-CN",
    )
    ctx.add_init_script(f"localStorage.setItem('qz_token', {json.dumps(TOKEN)})")

    page = ctx.new_page()

    # 1) 首页(新注册后)
    page.goto("http://localhost:5173/")
    page.wait_for_load_state("networkidle")
    page.wait_for_selector("text=总览", timeout=10000)
    shot(page, "01-home-fresh.png")

    # 2) 记支出 ¥35.5
    page.goto("http://localhost:5173/record/expense")
    page.wait_for_load_state("networkidle")
    page.wait_for_selector("text=餐饮", timeout=10000)
    shot(page, "02-record-expense-empty.png")

    page.get_by_role("button", name="餐饮").first.click()
    time.sleep(0.2)
    page.locator('button').filter(has_text="微信支付").first.click()
    time.sleep(0.2)
    press_digits(page, "35.5")
    time.sleep(0.3)
    shot(page, "03-record-expense-filled.png")

    confirm(page)
    page.wait_for_url("**/", timeout=8000)
    page.wait_for_load_state("networkidle")
    page.wait_for_selector("text=最近交易", timeout=10000)
    time.sleep(0.5)
    shot(page, "04-home-after-expense.png")

    # 3) 记收入 ¥5000
    page.goto("http://localhost:5173/record/income")
    page.wait_for_load_state("networkidle")
    page.wait_for_selector("text=工资", timeout=10000)
    shot(page, "05-record-income-empty.png")

    page.get_by_role("button", name="工资").first.click()
    time.sleep(0.2)
    page.locator('button').filter(has_text="银行卡").first.click()
    time.sleep(0.2)
    press_digits(page, "5000")
    time.sleep(0.3)
    shot(page, "06-record-income-filled.png")

    confirm(page)
    page.wait_for_url("**/", timeout=8000)
    page.wait_for_load_state("networkidle")
    page.wait_for_selector("text=最近交易", timeout=10000)
    time.sleep(0.5)
    shot(page, "07-home-after-income.png")

    # 4-9) 后续各页
    for url, wait_text, fname in [
        ("http://localhost:5173/reports/monthly", "月度统计", "08-report-monthly.png"),
        ("http://localhost:5173/reports/yearly", "年度统计", "09-report-yearly.png"),
        ("http://localhost:5173/accounts", "资产净值", "10-accounts.png"),
        ("http://localhost:5173/transactions", "全部交易", "11-transactions.png"),
        ("http://localhost:5173/profile/edit", "编辑资料", "12-profile-edit.png"),
        ("http://localhost:5173/accounts/new", "添加账户", "13-account-add.png"),
    ]:
        page.goto(url)
        page.wait_for_load_state("networkidle")
        page.wait_for_selector(f"text={wait_text}", timeout=10000)
        time.sleep(0.5)
        shot(page, fname)

    browser.close()
    print(f"\n[done] {USERNAME}  all screenshots in {OUT}")