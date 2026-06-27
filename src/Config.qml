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

    readonly property real defaultPanelWidth: 420

    // ── 默认显示的标签页 ──
    property int defaultTab: 0  // 0=todo, 1=idea, 2=log

    // ── 字体大小 ──
    property int fontTiny: 10    // 标签、日志日期
    property int fontSmall: 11   // 过滤器按钮、截止日期、灵感副标题、类型选择器
    property int fontBase: 13    // 标签页、输入框、待办/灵感标题、日志正文
    property int fontMedium: 14  // 空状态提示、状态图标、类型图标
    property int fontLarge: 16   // 刷新/关闭按钮
    property int fontXl: 18      // 头部标题

    // ── 字体默认值（恢复用）──
    readonly property int defaultFontTiny: 10
    readonly property int defaultFontSmall: 11
    readonly property int defaultFontBase: 13
    readonly property int defaultFontMedium: 14
    readonly property int defaultFontLarge: 16
    readonly property int defaultFontXl: 18

    // ── 主题 ──
    property string themeName: ""  // 空=Matugen自动, mocha/latte/frappe/macchiato=预设

    // ── 待办过滤器状态 ──
    property string todoFilter: "Pending"

    // ── 持久化路径 ──
    readonly property string settingsDir: homeDir + "/.config/star-panel"
    readonly property string settingsFile: settingsDir + "/settings.json"

    // ── 用户 Home 目录 ──
    readonly property string homeDir: Quickshell.env("HOME")

    // ── 从文件加载持久化设置 ──
    Process {
        id: settingsLoader
        command: ["bash", "-c", "cat " + config.settingsFile + " 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (typeof data.fontTiny   === "number") config.fontTiny   = data.fontTiny;
                    if (typeof data.fontSmall  === "number") config.fontSmall  = data.fontSmall;
                    if (typeof data.fontBase   === "number") config.fontBase   = data.fontBase;
                    if (typeof data.fontMedium === "number") config.fontMedium = data.fontMedium;
                    if (typeof data.fontLarge  === "number") config.fontLarge  = data.fontLarge;
                    if (typeof data.fontXl     === "number") config.fontXl     = data.fontXl;
                    if (typeof data.panelWidth === "number") config.panelWidth = data.panelWidth;
                    if (typeof data.animationDuration === "number") config.animationDuration = data.animationDuration;
                    if (typeof data.themeName  === "string") config.themeName  = data.themeName;
                    if (typeof data.todoFilter === "string") config.todoFilter = data.todoFilter;
                } catch (e) {}
            }
        }
    }

    // ── 持久化保存（300ms 防抖）──
    function saveSettings() {
        saveDebounce.restart();
    }

    Timer {
        id: saveDebounce
        interval: 300
        repeat: false
        onTriggered: {
            var data = {
                themeName: themeName,
                panelWidth: panelWidth,
                animationDuration: animationDuration,
                fontTiny: fontTiny,
                fontSmall: fontSmall,
                fontBase: fontBase,
                fontMedium: fontMedium,
                fontLarge: fontLarge,
                fontXl: fontXl,
                todoFilter: todoFilter
            };
            var json = JSON.stringify(data, null, 2);
            var safeDir = settingsDir.replace(/'/g, "'\\''");
            var safeFile = settingsFile.replace(/'/g, "'\\''");
            Quickshell.execDetached([
                "bash", "-c",
                "mkdir -p '" + safeDir + "' && printf '%s\\n' " + shellQuote(json) + " > '" + safeFile + "'"
            ]);
        }
    }

    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }
}
