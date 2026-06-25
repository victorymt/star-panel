import QtQuick
import Quickshell
import Quickshell.Io

/// Config — star-panel 配置单例
Item {
    id: config

    // ── 面板配置 ──
    property real panelWidth: 420
    property real panelMargin: 8
    property real panelRadius: 16
    property real animationDuration: 280

    // ── 数据刷新间隔（毫秒） ──
    property real refreshInterval: 30000

    // ── 默认显示的标签页 ──
    property int defaultTab: 0  // 0=todo, 1=idea, 2=log

    // ── CLI 命令 ──
    property string starcatchBin: "starcatch"

    // ── 用户 Home 目录 ──
    readonly property string homeDir: Quickshell.env("HOME")
}
