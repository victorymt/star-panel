import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// LogList — 日志列表组件
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
            text: "📓 暂无日志\n今天还没有记录哦~"
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
            mid: colors ? colors.peach : "#fab387"
        }
    }

    // ── 日志列表 ──
    ListView {
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
            implicitHeight: Math.max(56, contentColumn.implicitHeight + 16)

            contentItem: ColumnLayout {
                id: contentColumn
                spacing: 2

                Text {
                    text: modelData.content || ""
                    color: colors ? colors.text : "#cdd6f4"
                    font.pixelSize: cfg.fontBase
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 2
                    wrapMode: Text.WordWrap
                }

                Text {
                    text: modelData.title || ""
                    color: colors ? colors.overlay0 : "#6c7086"
                    font.pixelSize: cfg.fontTiny
                    elide: Text.ElideRight
                    Layout.fillWidth: true
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
        }
    }
}
