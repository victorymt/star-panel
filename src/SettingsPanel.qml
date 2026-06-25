import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// SettingsPanel — 设置面板（字体大小调整）
Popup {
    id: root

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: true

    implicitWidth: 300
    implicitHeight: settingsColumn.implicitHeight + padding * 2
    padding: 16

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    background: Rectangle {
        radius: 12
        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
    }

    contentItem: ColumnLayout {
        id: settingsColumn
        spacing: 8

        // 标题
        Text {
            text: "⚙ 设置"
            color: theme.text
            font.pixelSize: cfg.fontXl
            font.bold: true
            Layout.bottomMargin: 4
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
        }

        // 字体大小设置行
        Repeater {
            model: [
                { label: "标签 / 日期",    key: "fontTiny" },
                { label: "副标题 / 过滤",  key: "fontSmall" },
                { label: "正文 / 标题",    key: "fontBase" },
                { label: "空状态 / 图标",  key: "fontMedium" },
                { label: "按钮",           key: "fontLarge" },
                { label: "头部标题",       key: "fontXl" }
            ]

            delegate: RowLayout {
                required property var modelData
                spacing: 8

                Text {
                    text: modelData.label
                    color: theme.subtext0
                    font.pixelSize: cfg.fontSmall
                    Layout.preferredWidth: 100
                }

                Text {
                    text: cfg[modelData.key]
                    color: theme.text
                    font.pixelSize: cfg.fontBase
                    font.bold: true
                    Layout.preferredWidth: 24
                    horizontalAlignment: Text.AlignHCenter
                }

                Button {
                    flat: true
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    enabled: cfg[modelData.key] > 6
                    onClicked: cfg[modelData.key] -= 1

                    contentItem: Text {
                        text: "−"
                        color: enabled ? theme.subtext0 : theme.overlay0
                        font.pixelSize: cfg.fontBase
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                            : "transparent"
                    }
                }

                Button {
                    flat: true
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    enabled: cfg[modelData.key] < 40
                    onClicked: cfg[modelData.key] += 1

                    contentItem: Text {
                        text: "+"
                        color: enabled ? theme.subtext0 : theme.overlay0
                        font.pixelSize: cfg.fontBase
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                            : "transparent"
                    }
                }

                Text {
                    text: "Aa"
                    color: theme.subtext1
                    font.pixelSize: cfg[modelData.key]
                    Layout.preferredWidth: 20
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
        }

        Text {
            text: "修改即时生效 · 重启后恢复默认"
            color: theme.overlay0
            font.pixelSize: cfg.fontTiny
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
