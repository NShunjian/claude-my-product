#!/usr/bin/env bash
# admin-smoke.sh — 端到端冒烟测试 admin 子系统
# 用法: ADMIN_BOOTSTRAP_USERNAME=foo ADMIN_BOOTSTRAP_PASSWORD=bar ./admin-smoke.sh
#   或 ./admin-smoke.sh  (默认 admin/admin123)
# 依赖: curl, jq
set -eo pipefail

BASE_URL="${BASE_URL:-http://localhost:4001}"
ADMIN_USER="${ADMIN_BOOTSTRAP_USERNAME:-${ADMIN_USER:-admin}}"
ADMIN_PASS="${ADMIN_BOOTSTRAP_PASSWORD:-${ADMIN_PASS:-admin123}}"

# 颜色
GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

ok()    { echo -e "${GREEN}✓${NC} $1"; PASS=$((PASS+1)); }
bad()   { echo -e "${RED}✗${NC} $1"; FAIL=$((FAIL+1)); }
skip()  { echo -e "${YELLOW}⚠${NC} $1"; SKIP=$((SKIP+1)); }
hdr()   { echo -e "\n${YELLOW}== $1 ==${NC}"; }

# ---- 1. 登录 ----
hdr "1. POST /api/auth/login (${ADMIN_USER})"
LOGIN_BODY=$(jq -n --arg u "$ADMIN_USER" --arg p "$ADMIN_PASS" \
  '{username:$u, password:$p}')
LOGIN_RES=$(curl -fsS -X POST "$BASE_URL/api/auth/login" \
  -H "Content-Type: application/json" -d "$LOGIN_BODY") || {
  bad "登录失败:请确认 ADMIN_BOOTSTRAP_USERNAME/PASSWORD 与 .env 一致,且后端已启动"
  exit 1
}
TOKEN=$(echo "$LOGIN_RES" | jq -r '.data.token')
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
  bad "登录成功但未拿到 token"
  exit 1
fi
ok "登录成功"

AUTH="Authorization: Bearer $TOKEN"

# ---- 2. /me ----
hdr "2. GET /api/admin/auth/me"
ME=$(curl -fsS "$BASE_URL/api/admin/auth/me" -H "$AUTH")
ME_USER=$(echo "$ME" | jq -r '.data.username')
ME_SUPER=$(echo "$ME" | jq -r '.data.isSuperAdmin')
if [ "$ME_USER" = "$ADMIN_USER" ] && [ "$ME_SUPER" = "true" ]; then
  ok "/me 校验通过: user=$ME_USER super=$ME_SUPER"
else
  bad "/me 数据异常: $ME"
fi

# ---- 3. dashboard ----
hdr "3. GET /api/admin/dashboard"
DASH=$(curl -fsS "$BASE_URL/api/admin/dashboard" -H "$AUTH")
DASH_OK=$(echo "$DASH" | jq -r '.data.userCount != null and .data.bookCount != null')
if [ "$DASH_OK" = "true" ]; then
  ok "dashboard 字段齐全"
else
  bad "dashboard 缺失字段: $DASH"
fi

# ---- 4. users list ----
hdr "4. GET /api/admin/users"
USERS=$(curl -fsS "$BASE_URL/api/admin/users?page=1&size=5" -H "$AUTH")
USERS_TOTAL=$(echo "$USERS" | jq -r '.data.total')
if [ -n "$USERS_TOTAL" ] && [ "$USERS_TOTAL" != "null" ]; then
  ok "users 总数: $USERS_TOTAL"
else
  bad "users 列表异常"
fi

# ---- 5. categories ----
hdr "5. GET /api/admin/categories"
CATS=$(curl -fsS "$BASE_URL/api/admin/categories?page=1&size=5" -H "$AUTH")
CATS_TOTAL=$(echo "$CATS" | jq -r '.data.total')
if [ -n "$CATS_TOTAL" ] && [ "$CATS_TOTAL" != "null" ]; then
  ok "categories 总数: $CATS_TOTAL"
else
  bad "categories 列表异常"
fi

# ---- 6. books ----
hdr "6. GET /api/admin/books"
BOOKS=$(curl -fsS "$BASE_URL/api/admin/books?page=1&size=5" -H "$AUTH")
BOOKS_TOTAL=$(echo "$BOOKS" | jq -r '.data.total')
if [ -n "$BOOKS_TOTAL" ] && [ "$BOOKS_TOTAL" != "null" ]; then
  ok "books 总数: $BOOKS_TOTAL"
else
  bad "books 列表异常"
fi

# ---- 7. records ----
hdr "7. GET /api/admin/records"
RECS=$(curl -fsS "$BASE_URL/api/admin/records?page=1&size=5" -H "$AUTH")
RECS_TOTAL=$(echo "$RECS" | jq -r '.data.total')
if [ -n "$RECS_TOTAL" ] && [ "$RECS_TOTAL" != "null" ]; then
  ok "records 总数: $RECS_TOTAL"
else
  bad "records 列表异常"
fi

# ---- 8. audit-logs (super_admin 限定) ----
hdr "8. GET /api/admin/audit-logs"
AUDIT=$(curl -fsS "$BASE_URL/api/admin/audit-logs?page=1&size=5" -H "$AUTH")
AUDIT_TOTAL=$(echo "$AUDIT" | jq -r '.data.total')
if [ -n "$AUDIT_TOTAL" ] && [ "$AUDIT_TOTAL" != "null" ]; then
  ok "audit-logs 总数: $AUDIT_TOTAL"
else
  bad "audit-logs 列表异常"
fi

# ---- 9. 401 无 token ----
hdr "9. NEG: 无 Authorization 头"
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' "$BASE_URL/api/admin/users")
if [ "$HTTP_CODE" = "401" ]; then
  ok "无 token 正确返回 401"
else
  bad "期望 401, 实际 $HTTP_CODE"
fi

# ---- 10. 403 错误权限码(用一个非 super_admin 账号) ----
hdr "10. NEG: 非 super_admin 访问 audit-logs (skip if no test user)"
TEST_USER="${ADMIN_TEST_USER:-}"
TEST_PASS="${ADMIN_TEST_PASS:-}"
if [ -n "$TEST_USER" ] && [ -n "$TEST_PASS" ]; then
  TEST_TOKEN=$(curl -fsS -X POST "$BASE_URL/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg u "$TEST_USER" --arg p "$TEST_PASS" '{username:$u, password:$p}')" \
    | jq -r '.data.token') || TEST_TOKEN=""
  if [ -n "$TEST_TOKEN" ] && [ "$TEST_TOKEN" != "null" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
      "$BASE_URL/api/admin/audit-logs" \
      -H "Authorization: Bearer $TEST_TOKEN")
    if [ "$HTTP_CODE" = "403" ]; then
      ok "非 super_admin 正确被 403"
    else
      bad "期望 403, 实际 $HTTP_CODE"
    fi
  else
    skip "测试账号 $TEST_USER 登录失败,跳过 403 测试"
  fi
else
  skip "未配置 ADMIN_TEST_USER,跳过 403 测试"
fi

# ---- 汇总 ----
hdr "结果"
echo -e "  ${GREEN}通过: $PASS${NC}  ${RED}失败: $FAIL${NC}  ${YELLOW}跳过: $SKIP${NC}"
[ "$FAIL" -eq 0 ]
