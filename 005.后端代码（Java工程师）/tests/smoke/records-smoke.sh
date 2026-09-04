#!/usr/bin/env bash
# 005 Java 后端 — 账目域冒烟脚本(占位骨架)
#
# 覆盖目标(按 005-java-backend.md §7.1):
#   - 创建 expense 100 → 余额视图实时反映
#   - 创建 income 200 → 余额 +
#   - 创建 transfer A→B 50 → A 减 50,B 加 50
#   - 错误码触发:3011 / 3014 / 3017
#   - 7 维过滤组合
#
# 前置:tests/smoke/user-smoke.sh 已通过 + 至少 1 个账本 + 2 个账户
#
# 报告输出:tests/smoke/records-smoke.log → 由 test:report:copy 同步

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4001}"
LOG="${LOG:-tests/smoke/records-smoke.log}"

mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "records-smoke start at $(date)"
echo "=========================================="

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

# TODO(impl):
# - 复用 user-smoke 的 token
# - 1. create account A + B
# - 2. expense A 100 → /api/accounts/{A_uuid} 验证余额 = -100
# - 3. income A 200 → 余额 = +100
# - 4. transfer A→B 50 → A=+50, B=+50
# - 5. expense 缺 categoryId → 3011
# - 6. transfer A→A → 3014
# - 7. account 不属于 book → 3017

echo "(placeholder — to be implemented)"
echo "records-smoke done at $(date)"