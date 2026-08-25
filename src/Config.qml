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

    // ── 字体与界面缩放 ──
    // 所有字号从同一比例派生，避免正文、标题和控件被分别调整后层级倒置。
    readonly property int defaultFontTiny: 10
    readonly property int defaultFontSmall: 11
    readonly property int defaultFontBase: 13
    readonly property int defaultFontMedium: 14
    readonly property int defaultFontLarge: 16
    readonly property int defaultFontXl: 18
    readonly property real defaultUiScale: 1.0

    property real uiScale: defaultUiScale
    readonly property int fontTiny: Math.round(defaultFontTiny * uiScale)
    readonly property int fontSmall: Math.round(defaultFontSmall * uiScale)
    readonly property int fontBase: Math.round(defaultFontBase * uiScale)
    readonly property int fontMedium: Math.round(defaultFontMedium * uiScale)
    readonly property int fontLarge: Math.round(defaultFontLarge * uiScale)
    readonly property int fontXl: Math.round(defaultFontXl * uiScale)
    readonly property int compactControlHeight: Math.max(32, fontSmall + 16)
    readonly property int controlHeight: Math.max(36, fontBase + 18)
    readonly property int iconButtonSize: Math.max(32, fontLarge + 12)

    // ── 主题 ──
    property string themeName: ""  // 空=Matugen自动, mocha/latte/frappe/macchiato=预设

    // ── 待办过滤器状态 ──
    property string todoFilter: "Pending"

    // ── 日志时间范围：0=全部，1/3/7/30=最近 N 天 ──
    property int logFilterDays: 3

    // ── 持久化路径 ──
    readonly property string settingsDir: homeDir + "/.config/star-panel"
    readonly property string settingsFile: settingsDir + "/settings.json"

    // ── 用户 Home 目录 ──
    readonly property string homeDir: Quickshell.env("HOME")

    // 可通过 STARCATCH_BIN 覆盖，所有命令统一从这里读取。
    readonly property string starcatchPath: Quickshell.env("STARCATCH_BIN") || "starcatch"

    // ── 从文件加载持久化设置 ──
    Process {
        id: settingsLoader
        command: ["bash", "-c", "cat " + config.shellQuote(config.settingsFile) + " 2>/dev/null || echo '{}'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var data = JSON.parse(this.text.trim());
                    if (typeof data.uiScale === "number") {
                        config.uiScale = config.normalizeUiScale(data.uiScale);
                    } else if (typeof data.fontBase === "number") {
                        // 兼容旧版六级字号设置，以正文大小推导统一比例。
                        config.uiScale = config.normalizeUiScale(data.fontBase / config.defaultFontBase);
                    }
                    if (typeof data.panelWidth === "number") config.panelWidth = data.panelWidth;
                    if (typeof data.animationDuration === "number") config.animationDuration = data.animationDuration;
                    if (typeof data.themeName  === "string") config.themeName  = data.themeName;
                    if (typeof data.todoFilter === "string") config.todoFilter = data.todoFilter;
                    if (typeof data.logFilterDays === "number")
                        config.logFilterDays = config.normalizeLogFilterDays(data.logFilterDays);
                } catch (e) {
                    console.warn("star-panel: failed to parse settings.json:", e.message);
                }
                // 设置加载完成后统一初始化主题，避免与 Colors.qml 的 matugen 读取竞态
                if (typeof theme !== "undefined") theme.initFromSettings();
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
                uiScale: normalizeUiScale(uiScale),
                todoFilter: todoFilter,
                logFilterDays: normalizeLogFilterDays(logFilterDays)
            };
            var json = JSON.stringify(data, null, 2);
            Quickshell.execDetached([
                "bash", "-c",
                "mkdir -p " + shellQuote(settingsDir)
                    + " && printf '%s\\n' " + shellQuote(json)
                    + " > " + shellQuote(settingsFile)
            ]);
        }
    }

    function shellQuote(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    function normalizeLogFilterDays(value) {
        var days = Number(value);
        return days === 0 || days === 1 || days === 3 || days === 7 || days === 30 ? days : 3;
    }

    function normalizeUiScale(value) {
        var scale = Number(value);
        if (!isFinite(scale)) return defaultUiScale;
        return Math.max(0.8, Math.min(1.6, Math.round(scale * 20) / 20));
    }
}
