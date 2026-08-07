import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root

    property bool preview: false
    property var colors
    property int textSize: 12

    signal modeSelected(bool preview)

    implicitWidth: 108
    implicitHeight: 26
    radius: 6
    color: colors ? Qt.rgba(colors.surface0.r, colors.surface0.g, colors.surface0.b, 0.7) : "#313244"
    border.width: 1
    border.color: colors ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.45) : "#45475a"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 2
        spacing: 2

        Repeater {
            model: [
                { label: "编辑", preview: false },
                { label: "预览", preview: true }
            ]

            delegate: Button {
                required property var modelData

                Layout.fillWidth: true
                Layout.fillHeight: true
                flat: true
                onClicked: root.modeSelected(modelData.preview)

                contentItem: Text {
                    text: modelData.label
                    color: root.preview === modelData.preview
                        ? (root.colors ? root.colors.text : "#cdd6f4")
                        : (root.colors ? root.colors.subtext1 : "#a6adc8")
                    font.pixelSize: root.textSize
                    font.bold: root.preview === modelData.preview
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 4
                    color: root.preview === modelData.preview
                        ? (root.colors ? Qt.rgba(root.colors.surface1.r, root.colors.surface1.g, root.colors.surface1.b, 0.72) : "#45475a")
                        : parent.hovered
                            ? (root.colors ? Qt.rgba(root.colors.surface1.r, root.colors.surface1.g, root.colors.surface1.b, 0.35) : "#3b3d52")
                            : "transparent"
                }
            }
        }
    }
}
