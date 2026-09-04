#!/usr/bin/env bash
# 005 Java 后端 — 用户域冒烟脚本(占位骨架)
#
# 覆盖目标(按 005-java-backend.md §5.5):
#   1. POST /api/auth/register → 拿 token
#   2. GET  /api/auth/me        → 返当前用户
#   3. PATCH /api/users/me      → 改昵称
#   4. POST /api/users/me/password → 改密
#   5. 旧 token 操作 → 1401 (V8 token_version 生效)
#   6. POST /api/auth/login     → 重新登录
#
# 前置:
#   - 后端已起:java -Dspring.profiles.active=dev -jar target/qingzhang-java-backend-*.jar
#   - 或者:test profile 跑 mvn test 时这个脚本跳过
#
# 退出码:0=全部通过,1=任一失败
#
# 用法:
#   BASE_URL=http://localhost:4001 ./tests/smoke/user-smoke.sh
#   报告输出:tests/smoke/user-smoke.log → 由 test:report:copy 同步到 008.项目测试/测试报告/005-java-backend/smoke/

set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:4001}"
USERNAME="authtest_smoke_$(date +%s)"
PASSWORD="SmokeTest@12345"
LOG="${LOG:-tests/smoke/user-smoke.log}"

mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "=========================================="
echo "user-smoke start at $(date)"
echo "BASE_URL=$BASE_URL USERNAME=$USERNAME"
echo "=========================================="

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

# TODO(impl):
# - jq / curl 检测
# - 1. register
# - 2. me with token
# - 3. PATCH nickname
# - 4. PATCH password
# - 5. 旧 token 调 /api/users/me → 401
# - 6. login with new password
# - 7. delete-test user (admin API 或直接 SQL)

echo "(placeholder — to be implemented)"
echo "user-smoke done at $(date)"