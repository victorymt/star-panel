import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/// StarPanel — 负一屏主窗口
/// 从右侧滑出，展示 Starcatch 的三类数据：Todo / Idea / Log
PanelWindow {
    id: panel

    // ── Wayland 属性 ──
    WlrLayershell.namespace: "qs-star-panel"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    // ── 尺寸与定位 ──
    readonly property real panelWidth: cfg.panelWidth
    readonly property real panelMargin: cfg.panelMargin

    // PanelWindow 在 WlrLayershell 模式下由 layershell 协议管理位置
    implicitWidth: panelWidth + panelMargin * 2
    implicitHeight: screen.height
    color: "transparent"

    // 让窗口靠右填充
    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    anchors.left: false

    // ── 公开刷新接口（供子组件调用） ──
    function reloadData(type) {
        if (type === "todo")      { dataFetcher.fetchTodos(); }
        else if (type === "idea") { dataFetcher.fetchIdeas(); }
        else if (type === "log")  { dataFetcher.fetchLogs(); }
        else                      { dataFetcher.reload(); }  // fallback: all
    }

    // ── 配置 & 主题色 ──
    Colors { id: theme }
    Config { id: cfg }

    // ── 主题预设应用 ──
    Connections {
        target: cfg
        function onThemeNameChanged() {
            if (cfg.themeName !== "") theme.applyPreset(cfg.themeName);
        }
    }

    // ── 显隐控制 ──
    property bool panelVisible: false
    property real slideOffset: -(panelWidth + panelMargin * 2)
    Behavior on slideOffset {
        NumberAnimation {
            duration: cfg.animationDuration
            easing.type: Easing.OutQuint
        }
    }

    visible: panelVisible || slideOffset > -(panelWidth + panelMargin * 2)

    onPanelVisibleChanged: {
        slideOffset = panelVisible ? 0 : -(panelWidth + panelMargin * 2);
    }

    // 宽度变化时更新隐藏位置，防止面板异常显示
    onPanelWidthChanged: {
        if (!panelVisible) {
            slideOffset = -(panelWidth + panelMargin * 2);
        }
    }

    Component.onCompleted: {
        slideOffset = -(panelWidth + panelMargin * 2);
        if (cfg.themeName !== "") theme.applyPreset(cfg.themeName);
        Qt.callLater(() => dataFetcher.reload());
    }

    // ── IPC 控制 ──
    IpcHandler {
        target: "panel"

        function toggle() {
            panel.panelVisible = !panel.panelVisible;
        }

        function show() {
            panel.panelVisible = true;
        }

        function hide() {
            panel.panelVisible = false;
        }
    }

    // ── 点击外部关闭（必须在 backdrop 之前，否则拦截所有事件） ──
    MouseArea {
        anchors.fill: parent
        enabled: panelVisible
        onClicked: {
            if (mouse.x < backdrop.x || mouse.x > backdrop.x + backdrop.width) {
                panelVisible = false;
            }
        }
    }

    // ── 背景面板 ──
    Rectangle {
        id: backdrop
        x: panelMargin + slideOffset
        y: panelMargin
        width: panelWidth
        height: parent.height - panelMargin * 2
        radius: cfg.panelRadius

        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)

        // ── 内容区域 ──
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── 头部 ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "⭐ 星捕"
                    color: theme.text
                    font.pixelSize: cfg.fontXl
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: "↻"
                    flat: true
                    onClicked: dataFetcher.reload()
                    contentItem: Text {
                        text: "↻"
                        color: theme.subtext0
                        font.pixelSize: cfg.fontLarge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.6)
                            : "transparent"
                    }
                }

                Button {
                    text: "⚙"
                    flat: true
                    onClicked: settingsPanel.open()
                    contentItem: Text {
                        text: "⚙"
                        color: theme.subtext0
                        font.pixelSize: cfg.fontLarge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.6)
                            : "transparent"
                    }
                }

                Button {
                    text: "✕"
                    flat: true
                    onClicked: panel.panelVisible = false
                    contentItem: Text {
                        text: "✕"
                        color: theme.subtext0
                        font.pixelSize: cfg.fontLarge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.2)
                            : "transparent"
                    }
                }
            }

            // ── 选项卡 ──
            RowLayout {
                id: tabBar
                Layout.fillWidth: true
                spacing: 4
                property int currentIndex: cfg.defaultTab

                property var tabs: [
                    { label: "📋 待办" },
                    { label: "💭 灵感" },
                    { label: "📓 日志" }
                ]

                Repeater {
                    model: tabBar.tabs

                    delegate: Button {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        flat: true
                        onClicked: tabBar.currentIndex = index

                        contentItem: Text {
                            text: modelData.label
                            color: tabBar.currentIndex === index ? theme.text : theme.overlay0
                            font.pixelSize: cfg.fontBase
                            font.bold: tabBar.currentIndex === index
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 8
                            color: tabBar.currentIndex === index
                                ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                                : "transparent"
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
            }

            // ── 数据获取器 ──
            Item {
                id: dataFetcher

                property var todos: []
                property var ideas: []
                property var logs: []
                property bool loading: false

                function reload() {
                    loading = true;
                    fetchTodos();
                    fetchIdeas();
                    fetchLogs();
                }

                function fetchTodos() {
                    todoProcess.running = true;
                }

                function fetchIdeas() {
                    ideaProcess.running = true;
                }

                function fetchLogs() {
                    logProcess.running = true;
                }

                Process {
                    id: todoProcess
                    command: ["starcatch", "--json", "todo", "list", "--all"]
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            dataFetcher.todos = dataFetcher.parseTodos(this.text);
                            dataFetcher.checkDone();
                        }
                    }
                }

                Process {
                    id: ideaProcess
                    command: ["starcatch", "--json", "idea", "list", "-d", "7"]
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            dataFetcher.ideas = dataFetcher.parseIdeas(this.text);
                            dataFetcher.checkDone();
                        }
                    }
                }

                Process {
                    id: logProcess
                    command: ["starcatch", "--json", "log", "list", "-d", "3"]
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            dataFetcher.logs = dataFetcher.parseLogs(this.text);
                            dataFetcher.checkDone();
                        }
                    }
                }

                function checkDone() {
                    if (!todoProcess.running && !ideaProcess.running && !logProcess.running) {
                        dataFetcher.loading = false;
                    }
                }

                // ── JSON 解析辅助 ──
                function parseJson(text) {
                    try { return JSON.parse(text.trim()); } catch(e) { return []; }
                }

                function formatDate(iso) {
                    if (!iso) return "";
                    var parts = iso.split("T");
                    return parts[0].slice(5) + " " + parts[1].slice(0, 5);
                }

                // ── Todo JSON 映射 ──
                function parseTodos(text) {
                    var raw = parseJson(text);
                    var priorityIcon = { "P0": "🔴", "P1": "🟡", "P2": "🟢", "P3": "⚪" };
                    var statusIcon = { "Pending": "⬜", "Done": "✅", "Archived": "📦" };
                    return raw.map(function(item) {
                        return {
                            id: item.id,
                            rawStatus: item.status,
                            priority: priorityIcon[item.priority] || "🟢",
                            status: statusIcon[item.status] || "⬜",
                            title: item.title,
                            tags: item.tags || [],
                            due: item.due_date || "-"
                        };
                    });
                }

                // ── Idea JSON 映射 ──
                function parseIdeas(text) {
                    var raw = parseJson(text);
                    return raw.map(function(item) {
                        var time = formatDate(item.created_at);
                        var subtitle = item.source ? "from: " + item.source + " · " + time : time;
                        return {
                            title: item.title,
                            content: item.content || subtitle,
                            tags: item.tags || [],
                            time: time,
                            source: item.source || "?"
                        };
                    });
                }

                // ── Log JSON 映射 ──
                function parseLogs(text) {
                    var raw = parseJson(text);
                    return raw.map(function(item) {
                        var time = formatDate(item.created_at);
                        return {
                            title: time + (item.mood ? " · " + item.mood : ""),
                            content: item.content,
                            tags: item.tags || [],
                            time: time
                        };
                    });
                }
            }

            // ── 内容区域 ──
            StackLayout {
                id: tabContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex

                TodoList { id: todoList; items: dataFetcher.todos; loading: dataFetcher.loading }
                IdeaList { id: ideaList; items: dataFetcher.ideas; loading: dataFetcher.loading }
                LogList  { id: logList;  items: dataFetcher.logs;  loading: dataFetcher.loading }
            }

            // ── 底部快速输入 ──
            QuickInput {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
            }
        }

        // ── 设置面板 ──
        SettingsPanel { id: settingsPanel }
    }

    // ── 快捷键 ──
    Shortcut {
        sequence: "Escape"
        enabled: panelVisible
        onActivated: panelVisible = false
    }
}
