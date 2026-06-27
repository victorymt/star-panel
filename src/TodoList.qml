import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// TodoList — 待办列表组件
Item {
    id: root

    property var items: []
    property bool loading: false
    property string filterStatus: cfg.todoFilter
    readonly property var colors: theme
    property string searchText: ""

    // 过滤后的列表（状态 + 搜索）
    readonly property var filteredItems: {
        var all = items || [];
        var statusFiltered = all.filter(function(item) {
            return item.rawStatus === filterStatus;
        });
        if (!searchText.trim()) return statusFiltered;
        var q = searchText.trim().toLowerCase();
        return statusFiltered.filter(function(item) {
            return (item.title && item.title.toLowerCase().indexOf(q) >= 0)
                || (item.description && item.description.toLowerCase().indexOf(q) >= 0);
        });
    }

    onFilterStatusChanged: {
        if (cfg.todoFilter !== filterStatus) {
            cfg.todoFilter = filterStatus;
            cfg.saveSettings();
        }
    }

    // ── 过滤器栏 ──
    RowLayout {
        id: filterBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        spacing: 4

        property var filters: [
            { label: "⬜ 待办",   status: "Pending" },
            { label: "✅ 已完成", status: "Done" },
            { label: "📦 已归档", status: "Archived" }
        ]

        Repeater {
            model: filterBar.filters

            delegate: Button {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                flat: true
                onClicked: root.filterStatus = modelData.status

                contentItem: Text {
                    text: modelData.label
                    color: root.filterStatus === modelData.status ? colors.text : colors.overlay0
                    font.pixelSize: cfg.fontSmall
                    font.bold: root.filterStatus === modelData.status
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 6
                    color: root.filterStatus === modelData.status
                        ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.5)
                        : parent.hovered || parent.visualFocus
                            ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.25)
                            : "transparent"
                }
            }
        }
    }

    // ── 搜索框 ──
    TextField {
        id: searchField
        anchors.top: filterBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 4
        height: 28
        placeholderText: "🔍 搜索待办..."
        placeholderTextColor: colors ? colors.overlay0 : "#6c7086"
        color: colors ? colors.text : "#cdd6f4"
        font.pixelSize: cfg.fontSmall
        verticalAlignment: Text.AlignVCenter
        background: Rectangle {
            radius: 6
            color: Qt.rgba(colors.surface0.r, colors.surface0.g, colors.surface0.b, 0.4)
        }
        onTextChanged: root.searchText = text
    }

    // ── 空状态 ──
    Rectangle {
        anchors.top: searchField.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !loading && filteredItems.length === 0
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: {
                if (searchText.trim()) return "🔍 没有匹配的结果";
                if (items.length === 0) return "✨ 暂无待办\n一切都在掌控之中~";
                if (filterStatus === "Pending") return "⬜ 没有待办任务";
                if (filterStatus === "Done") return "✅ 没有已完成任务";
                return "📦 没有已归档任务";
            }
            color: colors ? colors.overlay0 : "#6c7086"
            font.pixelSize: cfg.fontMedium
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.6
        }
    }

    // ── 加载状态 ──
    BusyIndicator {
        anchors.centerIn: parent
        visible: loading
        palette {
            mid: colors ? colors.blue : "#89b4fa"
        }
    }

    // ── 待办列表 ──
    ListView {
        id: listView
        anchors.top: searchField.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        visible: !loading
        model: root.filteredItems
        clip: true
        spacing: 4

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: ItemDelegate {
            required property var modelData
            required property int index

            width: ListView.view.width
            implicitHeight: Math.max(48, contentRow.implicitHeight + 16)

            contentItem: RowLayout {
                id: contentRow
                spacing: 8

                // 优先级指示器
                Rectangle {
                    width: 4
                    height: parent.height
                    radius: 2
                    color: {
                        switch (modelData.priority) {
                            case "🔴": return colors ? colors.red : "#f38ba8";
                            case "🟡": return colors ? colors.peach : "#fab387";
                            default:   return colors ? colors.green : "#a6e3a1";
                        }
                    }
                }

                // 状态图标
                Text {
                    text: modelData.status === "✅" ? "✓" :
                          modelData.status === "📦" ? "📦" : "○"
                    color: colors ? colors.subtext0 : "#a6adc8"
                    font.pixelSize: cfg.fontMedium
                }

                // 标题 + 描述
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                        id: titleText
                        text: modelData.title
                        color: colors ? colors.text : "#cdd6f4"
                        font.pixelSize: cfg.fontBase
                        elide: Text.ElideRight
                        Layout.fillWidth: true

                        // 已完成状态用删除线
                        font.strikeout: modelData.status === "✅"
                        opacity: modelData.status === "✅" ? 0.6 : 1.0
                    }

                    Text {
                        text: modelData.description || ""
                        color: colors ? colors.subtext0 : "#a6adc8"
                        font.pixelSize: cfg.fontBase
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        visible: modelData.description && modelData.description !== ""
                        opacity: modelData.status === "✅" ? 0.5 : 0.85
                    }
                }

                // 截止日期
                Text {
                    text: modelData.due && modelData.due !== "-" ? modelData.due : ""
                    color: {
                        if (!modelData.due || modelData.due === "-") return "transparent";
                        var today = new Date();
                        today.setHours(0, 0, 0, 0);
                        var dueParts = modelData.due.split("-");
                        var due = new Date(parseInt(dueParts[0]), parseInt(dueParts[1]) - 1, parseInt(dueParts[2]));
                        var diff = Math.round((due - today) / (1000 * 60 * 60 * 24));
                        if (diff < 0) return colors ? colors.red : "#f38ba8";
                        if (diff < 2) return colors ? colors.peach : "#fab387";
                        return colors ? colors.overlay0 : "#6c7086";
                    }
                    font.pixelSize: cfg.fontSmall
                }

                // 标签
                TagList {
                    tags: modelData.tags
                    tagColor: colors ? colors.sapphire : "#74c7ec"
                }
            }

            background: Rectangle {
                radius: 8
                color: hovered
                    ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.3)
                    : "transparent"
            }

            // 点击循环状态: Pending → Done → Archived → Pending
            onClicked: {
                var id = modelData.id;
                var status = modelData.rawStatus;
                var cmd;
                if (status === "Pending")   { cmd = "done"; }
                else if (status === "Done") { cmd = "archive"; }
                else                        { cmd = "reopen"; }

                Quickshell.execDetached(["starcatch", "todo", cmd, id]);
                todoRefreshTimer.start();
            }
        }
    }

    // 延迟刷新：等 starcatch todo done/archive/reopen 完成
    Timer {
        id: todoRefreshTimer
        interval: 300
        repeat: false
        onTriggered: panel.reloadData("todo")
    }
}
