#!/usr/bin/env bash
# 共享库:后端/前端启停
# 用 source 引入,不要直接执行。
#
# 提供函数:
#   qz_root                   — 工作区根
#   qz_start_backend          — 启动后端
#   qz_start_frontend         — 启动前端
#   qz_stop                   — 停掉由本组脚本启动的进程
#   qz_status                 — 打印状态
#   qz_wait_port PORT LABEL LOG TIMEOUT — 等待端口就绪

set -u

# === 路径配置 ===
qz_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

ROOT="$(qz_root)"
BACKEND_DIR="$ROOT/005.后端代码（Java工程师）"
FRONTEND_DIR="$ROOT/003.前端代码（前端工程师）/frontend-react-java"
ADMIN_FRONTEND_DIR="$ROOT/006.后台管理系统（运营专员）"

# === 环境变量:source 仓库根 .env(若存在) ===
# 首次启动需配置 ADMIN_BOOTSTRAP_USERNAME / ADMIN_BOOTSTRAP_PASSWORD,
# 后端 AdminBootstrapService 会自动创建首个超管。
if [[ -f "$ROOT/.env" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$ROOT/.env"
  set +a
fi

BACKEND_PORT=4001
FRONTEND_PORT=5173
ADMIN_FRONTEND_PORT=5174

BACKEND_LOG="/tmp/qz-backend.log"
FRONTEND_LOG="/tmp/qz-frontend.log"
ADMIN_FRONTEND_LOG="/tmp/qz-admin-frontend.log"
BACKEND_PIDFILE="/tmp/qz-backend.pid"
FRONTEND_PIDFILE="/tmp/qz-frontend.pid"
ADMIN_FRONTEND_PIDFILE="/tmp/qz-admin-frontend.pid"
CLASSPATH_CACHE="/tmp/qz-m2-classpath.txt"

# === 端口→PID(无监听时返回非零) ===
port_pid() {
  local p
  p=$(lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | head -1)
  [[ -n "$p" ]] || return 1
  echo "$p"
}

# === 等待端口就绪 ===
qz_wait_port() {
  local port=$1 label=$2 timeout=${3:-60} log=${4:-}
  local pid i
  for i in $(seq 1 "$timeout"); do
    pid=$(port_pid "$port")
    [[ -n "$pid" ]] && { echo "  ✓ $label 已就绪 :$port (pid=$pid)"; return 0; }
    sleep 1
  done
  echo "  ✗ $label 启动超时 :$port"
  [[ -n "$log" ]] && echo "    看日志:$log"
  return 1
}

# === 后端 ===
qz_start_backend() {
  if pid=$(port_pid $BACKEND_PORT); then
    echo "  ⏭  后端已在运行 :$BACKEND_PORT (pid=$pid)"
    return 0
  fi
  echo "  (后端 :$BACKEND_PORT 无监听,准备启动)"

  echo "  → 编译 + 启动后端 (Spring Boot, Java 21 bytecode)..."
  mkdir -p "$BACKEND_DIR/target/classes"
  # ~/.m2 扫一次就缓存
  if [[ ! -s "$CLASSPATH_CACHE" ]]; then
    echo "    扫描 ~/.m2/repository (首次较慢)..."
    find ~/.m2/repository -name '*.jar' 2>/dev/null | tr '\n' ':' > "$CLASSPATH_CACHE"
  fi
  ALL_JARS=$(cat "$CLASSPATH_CACHE")
  LOMBOK_JAR=$(echo "$ALL_JARS" | tr ':' '\n' | grep -E '/lombok-[0-9]' | head -1)
  # Spring Boot 3 + logback:排除 commons-logging 与 slf4j-api 1.x
  FILTERED_JARS=$(echo "$ALL_JARS" | tr ':' '\n' \
    | grep -v 'commons-logging/' \
    | grep -v 'slf4j-api/1\.' \
    | tr '\n' ':')
  CP="${FILTERED_JARS}${BACKEND_DIR}/target/classes"

  ( cd "$BACKEND_DIR" && \
    javac --source 21 --target 21 -parameters -encoding UTF-8 \
          -classpath "$CP" -processorpath "$LOMBOK_JAR" -d target/classes \
          $(find src/main/java -name '*.java') \
    > "$BACKEND_LOG.compile" 2>&1 ) \
    || { echo "  ✗ 编译失败,看 $BACKEND_LOG.compile"; return 1; }

  ( cd "$BACKEND_DIR" && \
    nohup java -cp "$CP" com.qingzhang.QingZhangApplication \
      > "$BACKEND_LOG" 2>&1 & echo $! > "$BACKEND_PIDFILE" )
  qz_wait_port $BACKEND_PORT "后端" 90 "$BACKEND_LOG"
}

# === 前端 ===
qz_start_frontend() {
  if pid=$(port_pid $FRONTEND_PORT); then
    echo "  ⏭  前端已在运行 :$FRONTEND_PORT (pid=$pid)"
    return 0
  fi
  echo "  (前端 :$FRONTEND_PORT 无监听,准备启动)"

  echo "  → 安装依赖 + 启动前端 (Vite)..."
  if [[ ! -d "$FRONTEND_DIR/node_modules" ]]; then
    ( cd "$FRONTEND_DIR" && npm install --silent ) || { echo "  ✗ npm install 失败"; return 1; }
  fi

  ( cd "$FRONTEND_DIR" && nohup npm run dev > "$FRONTEND_LOG" 2>&1 & echo $! > "$FRONTEND_PIDFILE" )
  qz_wait_port $FRONTEND_PORT "前端" 30 "$FRONTEND_LOG"
}

# === 管理后台前端 ===
qz_start_admin_frontend() {
  if pid=$(port_pid $ADMIN_FRONTEND_PORT); then
    echo "  ⏭  管理后台已在运行 :$ADMIN_FRONTEND_PORT (pid=$pid)"
    return 0
  fi
  echo "  (管理后台 :$ADMIN_FRONTEND_PORT 无监听,准备启动)"

  echo "  → 安装依赖 + 启动管理后台 (Vite, React 19)..."
  if [[ ! -d "$ADMIN_FRONTEND_DIR/node_modules" ]]; then
    ( cd "$ADMIN_FRONTEND_DIR" && npm install --silent ) || { echo "  ✗ npm install 失败"; return 1; }
  fi

  ( cd "$ADMIN_FRONTEND_DIR" && nohup npm run dev > "$ADMIN_FRONTEND_LOG" 2>&1 & echo $! > "$ADMIN_FRONTEND_PIDFILE" )
  qz_wait_port $ADMIN_FRONTEND_PORT "管理后台" 30 "$ADMIN_FRONTEND_LOG"
}

# === 全部停掉 ===
qz_stop() {
  qz_stop_backend
  qz_stop_frontend
}

qz_stop_backend() {
  if [[ -f "$BACKEND_PIDFILE" ]]; then
    pid=$(cat "$BACKEND_PIDFILE" 2>/dev/null || true)
    [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null && echo "  ✓ 已停 后端 pid=$pid"
    rm -f "$BACKEND_PIDFILE"
  fi
  pid=$(port_pid "$BACKEND_PORT" || true)
  [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null && echo "  ✓ 已停 后端 :$BACKEND_PORT pid=$pid"
}

qz_stop_frontend() {
  if [[ -f "$FRONTEND_PIDFILE" ]]; then
    pid=$(cat "$FRONTEND_PIDFILE" 2>/dev/null || true)
    [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null && echo "  ✓ 已停 前端 pid=$pid"
    rm -f "$FRONTEND_PIDFILE"
  fi
  pid=$(port_pid "$FRONTEND_PORT" || true)
  [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null && echo "  ✓ 已停 前端 :$FRONTEND_PORT pid=$pid"
}

qz_stop_admin_frontend() {
  if [[ -f "$ADMIN_FRONTEND_PIDFILE" ]]; then
    pid=$(cat "$ADMIN_FRONTEND_PIDFILE" 2>/dev/null || true)
    [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null && echo "  ✓ 已停 管理后台 pid=$pid"
    rm -f "$ADMIN_FRONTEND_PIDFILE"
  fi
  pid=$(port_pid "$ADMIN_FRONTEND_PORT" || true)
  [[ -n "${pid:-}" ]] && kill "$pid" 2>/dev/null && echo "  ✓ 已停 管理后台 :$ADMIN_FRONTEND_PORT pid=$pid"
}

# === 状态 ===
qz_status() {
  pid=$(port_pid $BACKEND_PORT)
  [[ -n "$pid" ]] && echo "  后端 :$BACKEND_PORT pid=$pid" || echo "  后端 :$BACKEND_PORT (未运行)"
  pid=$(port_pid $FRONTEND_PORT)
  [[ -n "$pid" ]] && echo "  前端 :$FRONTEND_PORT pid=$pid" || echo "  前端 :$FRONTEND_PORT (未运行)"
  pid=$(port_pid $ADMIN_FRONTEND_PORT)
  [[ -n "$pid" ]] && echo "  管理后台 :$ADMIN_FRONTEND_PORT pid=$pid" || echo "  管理后台 :$ADMIN_FRONTEND_PORT (未运行)"
}
