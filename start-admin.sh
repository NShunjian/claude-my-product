#!/bin/bash
# 一键启停 admin 前端。
# - 缺 node_modules 自动 npm install
# - 缺 .env.local 自动从 .env.example 复制
# - 端口 5174 (与主前端 5173 错开)

set -e
cd "$(dirname "$0")/006.admin-frontend"

stop() {
  local pids
  pids=$(lsof -ti tcp:5174 2>/dev/null || true)
  if [ -z "$pids" ]; then
    echo ">> admin 前端未运行 (端口 5174 空闲)"
    return 0
  fi
  echo ">> 停止 admin 前端 (PIDs: $pids)"
  # 杀子进程组 (npm/vite/node),保留当前 shell
  kill $pids 2>/dev/null || true
  sleep 1
  kill -9 $pids 2>/dev/null || true
  echo ">> 已停止"
}

case "${1:-start}" in
  stop)   stop ;;
  status) lsof -ti tcp:5174 >/dev/null 2>&1 && echo ">> 端口 5174 在跑" || echo ">> 端口 5174 空闲" ;;
  start|"")
    if lsof -ti tcp:5174 >/dev/null 2>&1; then
      echo ">> 端口 5174 已被占用,先 stop:"; echo "   ./start-admin.sh stop"
      exit 1
    fi
    if [ ! -d node_modules ]; then
      echo ">> 安装依赖..."
      npm install
    fi
    if [ ! -f .env.local ] && [ -f .env.example ]; then
      echo ">> 复制 .env.example → .env.local"
      cp .env.example .env.local
    fi
    echo ">> 启动 admin 前端 (端口 5174)"
    exec npm run dev ;;
  *) echo "用法: $0 {start|stop|status}"; exit 1 ;;
esac