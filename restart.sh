#!/usr/bin/env bash
# restart.sh — 重启 star-panel
set -e

echo "🛑 停止 star-panel..."
STAR_PANEL_PATTERN='^(qs|quickshell)[[:space:]]+-c[[:space:]]+star-panel([[:space:]]|$)'
STAR_PANEL_PIDS=$(pgrep -f "$STAR_PANEL_PATTERN" || true)
if [[ -n "$STAR_PANEL_PIDS" ]]; then
  kill $STAR_PANEL_PIDS 2>/dev/null || true
  for _ in {1..20}; do
    pgrep -f "$STAR_PANEL_PATTERN" >/dev/null || break
    sleep 0.1
  done
  if pgrep -f "$STAR_PANEL_PATTERN" >/dev/null; then
    echo "❌ 无法停止已有 star-panel 实例"
    exit 1
  fi
  echo "   已停止"
else
  echo "   未运行"
fi

sleep 0.5

echo "🚀 启动 star-panel..."
quickshell -c star-panel --daemonize

sleep 1

if pgrep -f "$STAR_PANEL_PATTERN" > /dev/null; then
    PID=$(pgrep -f "$STAR_PANEL_PATTERN")
    echo "✅ star-panel 已启动 (PID: $PID)"
else
    echo "❌ 启动失败"
    exit 1
fi
