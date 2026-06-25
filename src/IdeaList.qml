import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// IdeaList — 灵感列表组件
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
            text: "💭 暂无灵感\n等待星光的降临~"
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
            mid: colors ? colors.mauve : "#cba6f7"
        }
    }

    // ── 灵感列表 ──
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
            implicitHeight: Math.max(52, contentColumn.implicitHeight + 16)

            contentItem: ColumnLayout {
                id: contentColumn
                spacing: 2

                Text {
                    text: modelData.title || "(untitled)"
                    color: colors ? colors.text : "#cdd6f4"
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: modelData.content || ""
                    color: colors ? colors.subtext0 : "#a6adc8"
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 1
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
        }
    }
}
