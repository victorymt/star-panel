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

    // ── 字体大小 ──
    property int fontTiny: 10    // 标签、日志日期
    property int fontSmall: 11   // 过滤器按钮、截止日期、灵感副标题、类型选择器
    property int fontBase: 13    // 标签页、输入框、待办/灵感标题、日志正文
    property int fontMedium: 14  // 空状态提示、状态图标、类型图标
    property int fontLarge: 16   // 刷新/关闭按钮
    property int fontXl: 18      // 头部标题

    // ── CLI 命令 ──
    property string starcatchBin: "starcatch"

    // ── 用户 Home 目录 ──
    readonly property string homeDir: Quickshell.env("HOME")
}
