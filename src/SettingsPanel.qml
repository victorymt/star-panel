import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// SettingsPanel — 设置面板
Popup {
    id: root

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: true

    implicitWidth: 300
    // 限制最大高度，短屏上"恢复默认/状态栏"按钮仍可达；超出部分用 ScrollView 滚动
    implicitHeight: Math.min(settingsColumn.implicitHeight + padding * 2,
                             parent ? parent.height * 0.8 : 600)
    padding: 16

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // Quickshell 下 Popup 不自动抢焦点，CloseOnEscape 失灵；
    // 打开时把焦点交给内容，Esc 才能由 contentItem 的 Keys 处理。
    onOpened: contentItem.forceActiveFocus()
    // 关闭后回到列表（vim normal mode），避免焦点丢失
    onClosed: panel.focusCurrentList()

    background: Rectangle {
        radius: 12
        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
    }

    contentItem: ScrollView {
        id: settingsScroll
        contentWidth: availableWidth
        clip: true

        // Escape 关闭弹窗（contentItem 拿到焦点后才生效，见 root.onOpened）
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        ColumnLayout {
            id: settingsColumn
            spacing: 8
            width: settingsScroll.availableWidth

        // 标题 + 关闭按钮
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "⚙ 设置"
                color: theme.text
                font.pixelSize: cfg.fontXl
                font.bold: true
                Layout.bottomMargin: 4
            }

            Item { Layout.fillWidth: true }

            Button {
                flat: true
                Layout.preferredWidth: cfg.iconButtonSize
                Layout.preferredHeight: cfg.iconButtonSize
                onClicked: root.close()
                contentItem: Text {
                    text: "✕"
                    color: theme.subtext1
                    font.pixelSize: cfg.fontBase
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                        : "transparent"
                }
            }
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
        }

        // ── 主题选择 ──
        RowLayout {
            spacing: 8

            Text {
                text: "主题"
                color: theme.subtext0
                font.pixelSize: cfg.fontSmall
                Layout.preferredWidth: 80
            }

            ComboBox {
                id: themeCombo
                Layout.fillWidth: true
                Layout.preferredHeight: cfg.controlHeight
                textRole: "label"

                model: [
                    { name: "",           label: "🤖 Auto（Matugen）" },
                    { name: "mocha",      label: "☕ Mocha" },
                    { name: "frappe",     label: "🍵 Frappé" },
                    { name: "macchiato",  label: "🌸 Macchiato" },
                    { name: "latte",      label: "🥛 Latte" }
                ]

                // 当前主题名到 ComboBox 索引的映射
                function indexFromName(name) {
                    for (var i = 0; i < model.length; i++) {
                        if (model[i].name === name) return i;
                    }
                    return 0;
                }

                Component.onCompleted: {
                    currentIndex = indexFromName(cfg.themeName);
                }

                Connections {
                    target: cfg
                    function onThemeNameChanged() {
                        themeCombo.currentIndex = themeCombo.indexFromName(cfg.themeName);
                    }
                }

                onActivated: {
                    cfg.themeName = model[currentIndex].name;
                    cfg.saveSettings();
                }

                contentItem: Text {
                    text: themeCombo.model[themeCombo.currentIndex]
                        ? themeCombo.model[themeCombo.currentIndex].label : ""
                    color: theme.text
                    font.pixelSize: cfg.fontSmall
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                        : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.6)
                    border.width: 1
                    border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
                }

                delegate: ItemDelegate {
                    required property var modelData
                    required property int index
                    width: themeCombo.width

                    contentItem: Text {
                        text: modelData.label
                        color: themeCombo.currentIndex === index ? theme.text : theme.subtext0
                        font.pixelSize: cfg.fontSmall
                        font.bold: themeCombo.currentIndex === index
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: highlighted
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                            : "transparent"
                    }
                }

                popup: Popup {
                    y: themeCombo.height
                    width: themeCombo.width
                    implicitHeight: contentItem.implicitHeight + padding * 2
                    padding: 4

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: themeCombo.popup.visible ? themeCombo.delegateModel : null
                    }

                    background: Rectangle {
                        radius: 8
                        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.96)
                        border.width: 1
                        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                    }
                }

                indicator: Text {
                    text: "▾"
                    color: theme.subtext0
                    font.pixelSize: cfg.fontTiny
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
        }

        // ── 面板宽度 ──
        RowLayout {
            spacing: 8

            Text {
                text: "面板宽度"
                color: theme.subtext0
                font.pixelSize: cfg.fontSmall
                Layout.preferredWidth: 100
            }

            Text {
                text: cfg.panelWidth + "px"
                color: theme.text
                font.pixelSize: cfg.fontBase
                font.bold: true
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                flat: true
                Layout.preferredWidth: cfg.iconButtonSize
                Layout.preferredHeight: cfg.iconButtonSize
                enabled: cfg.panelWidth > 280
                onClicked: { cfg.panelWidth -= 20; cfg.saveSettings(); }

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
                Layout.preferredWidth: cfg.iconButtonSize
                Layout.preferredHeight: cfg.iconButtonSize
                enabled: cfg.panelWidth < 900
                onClicked: { cfg.panelWidth += 20; cfg.saveSettings(); }

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
        }

        // ── 动画速度 ──
        RowLayout {
            spacing: 8

            Text {
                text: "动画速度"
                color: theme.subtext0
                font.pixelSize: cfg.fontSmall
                Layout.preferredWidth: 100
            }

            Text {
                text: cfg.animationDuration + "ms"
                color: theme.text
                font.pixelSize: cfg.fontBase
                font.bold: true
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                flat: true
                Layout.preferredWidth: cfg.iconButtonSize
                Layout.preferredHeight: cfg.iconButtonSize
                enabled: cfg.animationDuration > 100
                onClicked: { cfg.animationDuration -= 20; cfg.saveSettings(); }

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
                Layout.preferredWidth: cfg.iconButtonSize
                Layout.preferredHeight: cfg.iconButtonSize
                enabled: cfg.animationDuration < 600
                onClicked: { cfg.animationDuration += 20; cfg.saveSettings(); }

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
        }

        // 分隔线
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
        }

        // ── 界面缩放 ──
        RowLayout {
            spacing: 8

            Text {
                text: "界面缩放"
                color: theme.subtext1
                font.pixelSize: cfg.fontTiny
                font.bold: true
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "文字与控件"
                color: theme.subtext0
                font.pixelSize: cfg.fontSmall
                Layout.preferredWidth: 100
            }

            Text {
                text: Math.round(cfg.uiScale * 100) + "%"
                color: theme.text
                font.pixelSize: cfg.fontBase
                font.bold: true
                Layout.preferredWidth: 48
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                flat: true
                Layout.preferredWidth: cfg.iconButtonSize
                Layout.preferredHeight: cfg.iconButtonSize
                enabled: cfg.uiScale > 0.8
                onClicked: {
                    cfg.uiScale = cfg.normalizeUiScale(cfg.uiScale - 0.05);
                    cfg.saveSettings();
                }
                contentItem: Text {
                    text: "−"
                    color: enabled ? theme.subtext0 : theme.overlay0
                    font.pixelSize: cfg.fontBase
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered || parent.visualFocus
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                        : "transparent"
                }
            }

            Button {
                flat: true
                Layout.preferredWidth: cfg.iconButtonSize
                Layout.preferredHeight: cfg.iconButtonSize
                enabled: cfg.uiScale < 1.6
                onClicked: {
                    cfg.uiScale = cfg.normalizeUiScale(cfg.uiScale + 0.05);
                    cfg.saveSettings();
                }
                contentItem: Text {
                    text: "+"
                    color: enabled ? theme.subtext0 : theme.overlay0
                    font.pixelSize: cfg.fontBase
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered || parent.visualFocus
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                        : "transparent"
                }
            }

            Text {
                text: "Aa"
                color: theme.subtext1
                font.pixelSize: cfg.fontBase
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
        }

        Button {
            text: "恢复默认"
            flat: true
            Layout.fillWidth: true
            onClicked: {
                cfg.panelWidth = cfg.defaultPanelWidth;
                cfg.animationDuration = 280;
                cfg.uiScale = cfg.defaultUiScale;
                cfg.themeName  = "";
                cfg.todoFilter = "Pending";
                cfg.todoProjectFilter = "";
                cfg.logFilterDays = 3;
                cfg.saveSettings();
            }

            contentItem: Text {
                text: "恢复默认"
                color: theme.subtext0
                font.pixelSize: cfg.fontSmall
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                radius: 6
                color: parent.hovered
                    ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                    : "transparent"
            }
        }

        Text {
            text: "修改即时生效 · 重启后保留"
            color: theme.subtext1
            font.pixelSize: cfg.fontTiny
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
        }  // ColumnLayout
    }  // ScrollView (contentItem)
}
