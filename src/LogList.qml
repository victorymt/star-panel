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
    property string searchText: ""

    // ── 搜索框 ──
    TextField {
        id: searchField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        placeholderText: "🔍 搜索日志..."
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
        anchors.fill: parent
        visible: !loading && items.length === 0
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: {
                if (searchText.trim()) return "🔍 没有匹配的结果";
                return "📓 暂无日志\n今天还没有记录哦~";
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
            mid: colors ? colors.peach : "#fab387"
        }
    }

    // ── 日志列表 ──
    ListView {
        anchors.top: searchField.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !loading
        model: {
            if (!searchText.trim()) return root.items;
            var q = searchText.trim().toLowerCase();
            return root.items.filter(function(item) {
                return (item.content && item.content.toLowerCase().indexOf(q) >= 0)
                    || (item.title && item.title.toLowerCase().indexOf(q) >= 0);
            });
        }
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
