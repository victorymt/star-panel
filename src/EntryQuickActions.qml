import QtQuick
import QtQuick.Controls

Row {
    id: root

    property bool revealed: false
    property color editColor: "#89b4fa"
    property color copyColor: "#a6e3a1"
    property color hoverColor: "#45475a"
    property int iconSize: 12
    property int buttonSize: 26

    signal editRequested()
    signal copyRequested()

    spacing: 2
    opacity: revealed ? 1 : 0
    enabled: revealed

    Behavior on opacity {
        NumberAnimation { duration: 100 }
    }

    Button {
        flat: true
        width: root.buttonSize
        height: root.buttonSize
        onClicked: root.editRequested()

        contentItem: Text {
            text: "✎"
            color: root.editColor
            font.pixelSize: root.iconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 5
            color: parent.hovered ? root.hoverColor : "transparent"
        }

        ToolTip.text: "编辑"
        ToolTip.visible: hovered
        ToolTip.delay: 400
    }

    Button {
        flat: true
        width: root.buttonSize
        height: root.buttonSize
        onClicked: root.copyRequested()

        contentItem: Text {
            text: "⧉"
            color: root.copyColor
            font.pixelSize: root.iconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        background: Rectangle {
            radius: 5
            color: parent.hovered ? root.hoverColor : "transparent"
        }

        ToolTip.text: "复制"
        ToolTip.visible: hovered
        ToolTip.delay: 400
    }
}
