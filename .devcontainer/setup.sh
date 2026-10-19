#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.." || exit 1
ROOT="$(pwd)"
export COREPACK_ENABLE_STRICT=0
echo "=========================================="
echo " Roblox-MCP · Codespaces 初始化"
echo " 仓库: $ROOT"
echo "=========================================="
echo
echo "[1/3] 应用协议自适应补丁"
if [ -f .devcontainer/patch-connector.mjs ]; then
  [ -f connector.luau.bak ] || cp connector.luau connector.luau.bak 2>/dev/null || true
  node .devcontainer/patch-connector.mjs "$ROOT/connector.luau" || echo "  ✗ 补丁失败"
else
  echo "  ! 找不到补丁脚本"
fi
echo
echo "[2/3] 安装依赖"
if [ -d node_modules ] && [ -f node_modules/.package-lock.json ]; then
  echo "  node_modules 已存在，跳过"
else
  npm install --no-audit --no-fund 2>&1 | tail -5
fi
echo
echo "[3/3] 编译 TypeScript"
npm run build 2>&1 | tail -5
if [ -f dist/index.js ]; then echo "  ✓ dist/index.js 已生成"; else echo "  ✗ 编译失败"; exit 1; fi
echo
echo "=========================================="
echo " 初始化完成"
echo "=========================================="
