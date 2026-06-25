import QtQuick
import QtQuick.Layouts

/// TagList — 可复用的标签列表组件
/// 用法: TagList { tags: modelData.tags; tagColor: colors.sapphire }
Flow {
    id: root

    property var tags: []
    property color tagColor: "#74c7ec"

    visible: tags && tags.length > 0
    spacing: 2
    Layout.fillWidth: true

    Repeater {
        model: root.tags
        delegate: Rectangle {
            required property string modelData
            height: 18
            width: tagLabel.width + 8
            radius: 4
            color: Qt.rgba(root.tagColor.r, root.tagColor.g, root.tagColor.b, 0.15)

            Text {
                id: tagLabel
                text: modelData
                color: root.tagColor
                font.pixelSize: 10
                anchors.centerIn: parent
            }
        }
    }
}
