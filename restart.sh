#!/usr/bin/env bash
# restart.sh — 重启 star-panel
set -e

echo "🛑 停止 star-panel..."
pkill -f "quickshell.*star-panel" 2>/dev/null && echo "   已停止" || echo "   未运行"

sleep 0.5

echo "🚀 启动 star-panel..."
quickshell -c star-panel --daemonize

sleep 1

if pgrep -f "quickshell.*star-panel" > /dev/null; then
    PID=$(pgrep -f "quickshell.*star-panel")
    echo "✅ star-panel 已启动 (PID: $PID)"
else
    echo "❌ 启动失败"
    exit 1
fi
