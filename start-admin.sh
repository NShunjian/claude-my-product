#!/bin/bash
# 一键启动 admin 前端。
# - 缺 node_modules 自动 npm install
# - 缺 .env.local 自动从 .env.example 复制
# - 端口 5174 (与主前端 5173 错开)

set -e
cd "$(dirname "$0")/006.admin-frontend"

if [ ! -d node_modules ]; then
  echo ">> 安装依赖..."
  npm install
fi

if [ ! -f .env.local ] && [ -f .env.example ]; then
  echo ">> 复制 .env.example → .env.local"
  cp .env.example .env.local
fi

echo ">> 启动 admin 前端 (端口 5174)"
exec npm run dev