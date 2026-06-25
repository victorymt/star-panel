import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// TodoList — 待办列表组件
Item {
    id: root

    property var items: []
    property bool loading: false
    readonly property var colors: theme

    // ── 空状态 ──
    Rectangle {
        anchors.fill: parent
        visible: !loading && items.length === 0
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: "✨ 暂无待办\n一切都在掌控之中~"
            color: colors ? colors.overlay0 : "#6c7086"
            font.pixelSize: 14
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
        anchors.fill: parent
        visible: !loading
        model: root.items
        clip: true
        spacing: 4

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: ItemDelegate {
            required property var modelData
            required property int index

            width: ListView.view.width
            height: 48

            contentItem: RowLayout {
                spacing: 8

                // 优先级指示器
                Rectangle {
                    width: 4
                    height: parent.height
                    radius: 2
                    color: {
                        switch (modelData.priority) {
                            case "🔴": return "#f38ba8";  // red
                            case "🟡": return "#fab387";  // peach
                            default:   return "#a6e3a1";  // green
                        }
                    }
                }

                // 状态图标
                Text {
                    text: modelData.status === "✅" ? "✓" :
                          modelData.status === "📦" ? "📦" : "○"
                    color: colors ? colors.subtext0 : "#a6adc8"
                    font.pixelSize: 14
                }

                // 标题
                Text {
                    text: modelData.title
                    color: colors ? colors.text : "#cdd6f4"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                    Layout.fillWidth: true

                    // 已完成状态用删除线
                    font.strikeout: modelData.status === "✅"
                    opacity: modelData.status === "✅" ? 0.6 : 1.0
                }

                // 截止日期
                Text {
                    text: modelData.due && modelData.due !== "-" ? modelData.due : ""
                    color: {
                        if (!modelData.due || modelData.due === "-") return "transparent";
                        var today = new Date();
                        var due = Date.parse(modelData.due);
                        var diff = (due - today) / (1000 * 60 * 60 * 24);
                        if (diff < 0) return "#f38ba8";   // 过期
                        if (diff < 2) return "#fab387";   // 临近
                        return colors ? colors.overlay0 : "#6c7086";
                    }
                    font.pixelSize: 11
                }

                // 标签
                Flow {
                    visible: modelData.tags && modelData.tags.length > 0
                    spacing: 2
                    Repeater {
                        model: modelData.tags
                        delegate: Rectangle {
                            required property string modelData
                            height: 18
                            width: tagLabel.width + 8
                            radius: 4
                            color: Qt.rgba(colors.sapphire.r, colors.sapphire.g, colors.sapphire.b, 0.15)

                            Text {
                                id: tagLabel
                                text: modelData
                                color: colors ? colors.sapphire : "#74c7ec"
                                font.pixelSize: 10
                                anchors.centerIn: parent
                            }
                        }
                    }
                }
            }

            background: Rectangle {
                radius: 8
                color: hovered
                    ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.3)
                    : "transparent"
            }

            // 点击切换完成状态（将来可以扩展为 IPC 调用）
            onClicked: {
                // TODO: 调用 starcatch todo done <id>
            }
        }
    }
}
