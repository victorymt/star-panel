import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// QuickInput — 底部快速输入组件
/// Pipe 模式快速捕获灵感、待办、日志到 Starcatch
Item {
    id: root

    implicitHeight: 40

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: theme ? Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.6) : "#313244"
        border.width: 1
        border.color: textInput.activeFocus
            ? (theme ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.4) : Qt.rgba(0.54, 0.71, 0.98, 0.4))
            : (theme ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3) : Qt.rgba(0.27, 0.34, 0.38, 0.3))

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 6

            // 类型选择指示器
            Text {
                text: {
                    switch (typeSelector.currentIndex) {
                        case 0: return "📋";
                        case 1: return "💭";
                        case 2: return "📓";
                        default: return "📋";
                    }
                }
                font.pixelSize: 14
            }

            // 快速输入框
            TextInput {
                id: textInput
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                color: theme ? theme.text : "#cdd6f4"
                font.pixelSize: 13
                clip: true
                activeFocusOnPress: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "快速捕获... 按 Enter 提交"
                    color: theme ? theme.overlay0 : "#6c7086"
                    font.pixelSize: 13
                    visible: !parent.text
                }

                Keys.onReturnPressed: {
                    var inputText = textInput.text.trim();
                    if (inputText === "") return;

                    var type = typeSelector.types[typeSelector.currentIndex];
                    var safeText = "'" + inputText.replace(/'/g, "'\\''") + "'";

                    Quickshell.execDetached([
                        "bash", "-c",
                        "printf '%s\\n' " + safeText + " | starcatch pipe " + type
                    ]);

                    textInput.text = "";
                    textInput.focus = false;

                    // 延迟刷新列表，等 starcatch pipe 写入完成
                    refreshTimer.pendingType = type;
                    refreshTimer.start();
                }
            }

            // 类型切换按钮
            Button {
                id: typeSelector
                property var types: ["todo", "idea", "log"]
                property var labels: ["📋 待办", "💭 灵感", "📓 日志"]
                property int currentIndex: 0

                contentItem: Text {
                    text: typeSelector.labels[typeSelector.currentIndex]
                    color: theme ? theme.subtext0 : "#a6adc8"
                    font.pixelSize: 11
                }

                flat: true
                onClicked: {
                    typeSelector.currentIndex = (typeSelector.currentIndex + 1) % typeSelector.types.length;
                }

                background: Rectangle {
                    radius: 6
                    color: parent.hovered && theme
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                        : "transparent"
                }
            }
        }

        // 延迟刷新：等 starcatch pipe 写入完成后刷新面板数据
        Timer {
            id: refreshTimer
            interval: 400
            repeat: false
            property string pendingType: ""
            onTriggered: panel.reloadData(pendingType)
        }
    }
}
