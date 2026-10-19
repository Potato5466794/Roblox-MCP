#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"; PORT=16384; LOG_DIR="$ROOT/logs"
export COREPACK_ENABLE_STRICT=0
mkdir -p "$LOG_DIR"
echo "=========================================="
echo " Roblox-MCP · 启动桥接服务"
echo "=========================================="
if [ ! -f dist/index.js ]; then
  echo "  ! 未发现编译产物，先执行初始化..."
  bash .devcontainer/setup.sh || exit 1
fi
kill_stale() {
  local f pid cmd
  for f in /proc/[0-9]*/cmdline; do
    [ -r "$f" ] || continue
    pid="${f#/proc/}"; pid="${pid%/cmdline}"
    [ "$pid" = "$$" ] && continue
    cmd="$(tr '\0' ' ' < "$f" 2>/dev/null)"
    case "$cmd" in *"dist/index.js"*) echo "  停止旧实例 PID $pid"; kill -9 "$pid" 2>/dev/null || true ;; esac
  done
}
kill_stale
for _ in $(seq 1 20); do
  still=0
  for f in /proc/[0-9]*/cmdline; do
    [ -r "$f" ] || continue
    case "$(tr '\0' ' ' < "$f" 2>/dev/null)" in *"dist/index.js"*) still=1 ;; esac
  done
  [ "$still" = "0" ] && break
  sleep 0.5
done
echo "  启动服务..."
: > "$LOG_DIR/server.log"
nohup node dist/index.js > "$LOG_DIR/server.log" 2>&1 &
PID=$!
echo "$PID" > "$LOG_DIR/server.pid"
echo "  PID=$PID"
READY=0
for _ in $(seq 1 60); do
  curl -sS -m 2 -o /dev/null "http://127.0.0.1:${PORT}/api/status" 2>/dev/null && { READY=1; break; }
  sleep 0.5
done
if [ "$READY" != "1" ]; then
  echo "  ✗ 服务未就绪："; tail -20 "$LOG_DIR/server.log" | sed 's/^/    /'; exit 1
fi
echo "  ✓ 服务已就绪"
curl -sS -m 5 "http://127.0.0.1:${PORT}/api/status" | sed 's/^/    /'
echo
if command -v gh >/dev/null 2>&1 && [ -n "${CODESPACE_NAME:-}" ]; then
  gh codespace ports visibility "${PORT}:public" -c "$CODESPACE_NAME" >/dev/null 2>&1 \
    && echo "  ✓ 端口 ${PORT} 已设为 public" \
    || echo "  ! 请到 PORTS 面板手动设为 Public"
else
  echo "  ! 请到 PORTS 面板 → 端口 ${PORT} → 右键 → Port Visibility → Public"
fi
DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
if [ -n "${CODESPACE_NAME:-}" ]; then BASE="https://${CODESPACE_NAME}-${PORT}.${DOMAIN}"; else BASE="http://localhost:${PORT}"; fi
echo
echo "=========================================="
echo " 仪表盘   : ${BASE}/"
echo " 加载器   : ${BASE}/script.luau"
echo "=========================================="
echo " 注入（BridgeURL 必须带 https://）："
echo "   getgenv().BridgeURL = \"${BASE}\""
echo "   loadstring(game:HttpGet(\"${BASE}/script.luau\"))()"
echo "=========================================="
