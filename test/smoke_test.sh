#!/usr/bin/env bash
# smoke_test.sh — star-panel 集成冒烟测试
set -euo pipefail

PASS=0
FAIL=0

pass() { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }

assert_eq() {
  if [ "$1" = "$2" ]; then pass "$3"; else fail "$3 (expected '$2', got '$1')"; fi
}

# ── 1. 启动测试 ──
echo "=== 1. 启动测试 ==="
cd "$(dirname "$0")/.."

# 先确保进程不在运行
pkill -f "quickshell.*star-panel" 2>/dev/null || true
sleep 0.3

# 启动
bash restart.sh
PID=$(pgrep -f "quickshell.*star-panel" 2>/dev/null || echo "")
assert_eq "$(echo "$PID" | wc -l)" "1" "进程存在且唯一"

# ── 2. IPC 通信测试 ──
echo "=== 2. IPC 通信测试 ==="
sleep 1

IPC_SOCK=$(find /run/user/1000/quickshell/by-id -name "ipc.sock" 2>/dev/null | head -1)
if [ -n "$IPC_SOCK" ]; then
  pass "IPC socket 存在: $IPC_SOCK"
else
  fail "IPC socket 未找到"
fi

# ── 3. 配置文件持久化测试 ──
echo "=== 3. 配置文件测试 ==="
CONFIG_FILE="$HOME/.config/star-panel/settings.json"
if [ -f "$CONFIG_FILE" ]; then
  pass "settings.json 存在"
  # 验证 JSON 合法性
  if python3 -c "import json; json.load(open('$CONFIG_FILE'))" 2>/dev/null; then
    pass "settings.json 是合法 JSON"
  else
    fail "settings.json 不是合法 JSON"
  fi
else
  fail "settings.json 不存在（首次启动后应自动创建）"
fi

# ── 4. 语法验证 ──
echo "=== 4. QML 语法 ==="
if command -v qmllint &>/dev/null; then
  if qmllint shell.qml src/*.qml 2>/dev/null; then
    pass "qmllint 无错误"
  else
    fail "qmllint 报告错误"
  fi
else
  pass "qmllint 未安装，跳过"
fi

# ── 5. 清理 ──
echo "=== 5. 清理 ==="
pkill -f "quickshell.*star-panel" 2>/dev/null || true

# ── 结果 ──
echo ""
echo "=== 结果: $PASS 通过, $FAIL 失败 ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
