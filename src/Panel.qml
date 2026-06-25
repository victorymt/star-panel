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
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    // ── 尺寸与定位 ──
    readonly property real panelWidth: 420
    readonly property real panelMargin: 8

    // PanelWindow 在 WlrLayershell 模式下由 layershell 协议管理位置
    implicitWidth: panelWidth + panelMargin * 2
    implicitHeight: screen.height
    color: "transparent"

    // 让窗口靠右填充
    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    anchors.left: false

    // ── 主题色 ──
    Colors { id: theme }

    // ── 显隐控制 ──
    property bool panelVisible: false
    property real slideOffset: -(panelWidth + panelMargin * 2)
    Behavior on slideOffset {
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutQuint
        }
    }

    visible: panelVisible || slideOffset > -(panelWidth + panelMargin * 2)

    onPanelVisibleChanged: {
        slideOffset = panelVisible ? 0 : -(panelWidth + panelMargin * 2);
    }

    Component.onCompleted: {
        slideOffset = -(panelWidth + panelMargin * 2);
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

    // ── 背景面板 ──
    Rectangle {
        id: backdrop
        x: panelMargin + slideOffset
        y: panelMargin
        width: panelWidth
        height: parent.height - panelMargin * 2
        radius: 16

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
                    font.pixelSize: 18
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
                        font.pixelSize: 16
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
                        font.pixelSize: 16
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
                property int currentIndex: 0

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
                            font.pixelSize: 13
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
                    command: ["starcatch", "todo", "list", "--all"]
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            dataFetcher.todos = dataFetcher.parseCliOutput(this.text);
                            dataFetcher.checkDone();
                        }
                    }
                }

                Process {
                    id: ideaProcess
                    command: ["starcatch", "idea", "list", "-d", "7"]
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            dataFetcher.ideas = dataFetcher.parseCliOutput(this.text);
                            dataFetcher.checkDone();
                        }
                    }
                }

                Process {
                    id: logProcess
                    command: ["starcatch", "log", "list", "-d", "3"]
                    running: false
                    stdout: StdioCollector {
                        onStreamFinished: {
                            dataFetcher.logs = dataFetcher.parseCliOutput(this.text);
                            dataFetcher.checkDone();
                        }
                    }
                }

                function checkDone() {
                    if (!todoProcess.running && !ideaProcess.running && !logProcess.running) {
                        dataFetcher.loading = false;
                    }
                }

                function parseCliOutput(text) {
                    var lines = text.split('\n');
                    var items = [];
                    for (var i = 0; i < lines.length; i++) {
                        var line = lines[i].trim();
                        if (line === '' || line.startsWith('📋') || line.startsWith('📋 Todos') ||
                            line.startsWith('✅') || line.startsWith('📦') || line.startsWith('💭') ||
                            line.startsWith('📓') || line.startsWith('📋 待办') || line.startsWith('No')) {
                            continue;
                        }
                        var match = line.match(/^([🟢🟡🔴])\s+(⬜|✅|📦)\s+(.+?)(?:\s+\[(.+?)\])?\s*\|\s*due:\s*(.+)$/);
                        if (match) {
                            items.push({
                                priority: match[1],
                                status: match[2],
                                title: match[3],
                                tags: match[4] ? match[4].split(', ') : [],
                                due: match[5]
                            });
                        }
                    }
                    return items;
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
    }

    // ── 点击外部关闭 ──
    MouseArea {
        anchors.fill: parent
        enabled: panelVisible
        onClicked: {
            if (mouse.x < backdrop.x || mouse.x > backdrop.x + backdrop.width) {
                panelVisible = false;
            }
        }
    }

    // ── 快捷键 ──
    Shortcut {
        sequence: "Escape"
        enabled: panelVisible
        onActivated: panelVisible = false
    }
}
