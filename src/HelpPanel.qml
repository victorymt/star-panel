import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/// HelpPanel — 帮助面板（快捷键 / IPC 命令）
/// 由 QuickInput 的 :help 命令通过 panel.openHelp() 触发
Popup {
    id: root

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: true

    implicitWidth: 340
    // 限制最大高度，短屏上仍可滚动查看
    implicitHeight: Math.min(helpColumn.implicitHeight + padding * 2,
                             parent ? parent.height * 0.85 : 700)
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
        id: helpScroll
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
            id: helpColumn
            spacing: 6
            width: helpScroll.availableWidth

            // 标题 + 关闭按钮
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "❓ 帮助"
                    color: theme.text
                    font.pixelSize: cfg.fontXl
                    font.bold: true
                    Layout.bottomMargin: 2
                }

                Item { Layout.fillWidth: true }

                Button {
                    flat: true
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    onClicked: root.close()
                    contentItem: Text {
                        text: "✕"
                        color: theme.overlay0
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

            // 引导
            Text {
                text: "输入 :help 重新打开 · 输入框中 Esc 先回列表再关面板 · q/Ctrl+Q 任意位置关"
                color: theme.overlay0
                font.pixelSize: cfg.fontTiny
                Layout.fillWidth: true
                Layout.bottomMargin: 6
            }

            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
            }

            // ── 第一节：键盘快捷键 ──
            // 每条记录要么是 { section: "..." }（小节标题），要么是 { key, desc }（条目）
            Repeater {
                model: [
                    { section: "全局" },
                    { key: "Esc", desc: "关弹窗或关面板（输入框/搜索框中先回列表）" },
                    { key: "q / Ctrl+Q", desc: "任意位置关弹窗或关面板" },
                    { key: "Ctrl+1 / 2 / 3", desc: "切到 待办 / 灵感 / 日志" },
                    { key: "Ctrl+Tab", desc: "下一个标签" },
                    { key: "Ctrl+Shift+Tab", desc: "上一个标签" },
                    { key: "/", desc: "聚焦搜索框" },
                    { key: "Ctrl+R", desc: "刷新数据" },
                    { key: "Ctrl+,", desc: "打开设置" },
                    { section: "列表 · vim" },
                    { key: "j / k", desc: "下移 / 上移" },
                    { key: "h / l", desc: "上一个 / 下一个标签" },
                    { key: "gg", desc: "跳到顶部（1s 内按两次 g）" },
                    { key: "G", desc: "跳到底部" },
                    { key: "Ctrl+D / Ctrl+U", desc: "半页下 / 上" },
                    { key: "Ctrl+F / Ctrl+B", desc: "整页下 / 上" },
                    { key: "gt / gT", desc: "下一个 / 上一个标签" },
                    { key: "r / R", desc: "刷新当前列表 / 全部列表" },
                    { key: "o", desc: "聚焦快速输入（insert mode）" },
                    { key: ":", desc: "进命令模式" },
                    { key: "q", desc: "关弹窗或关面板" },
                    { key: "dd", desc: "删除当前项（再按 d 确认）" },
                    { key: "e", desc: "编辑当前项" },
                    { key: "Enter", desc: "查看详情" },
                    { key: "1 / 2 / 3", desc: "切 Todo 过滤器：待办 / 已完成 / 已归档" },
                    { section: "输入编辑 · emacs" },
                    { key: "Esc", desc: "清空 / 失焦" },
                    { key: "Ctrl+A / Ctrl+E", desc: "行首 / 行尾" },
                    { key: "Ctrl+B / Ctrl+F", desc: "左移 / 右移" },
                    { key: "Ctrl+K / Ctrl+U", desc: "删到行尾 / 清空输入" },
                    { section: "命令模式" },
                    { key: "Tab / Shift+Tab", desc: "切换类型（正/反向）；命令模式切换候选" },
                    { key: ":", desc: "进入命令模式" },
                    { key: ":q", desc: "关闭面板" },
                    { key: ":r / :reload", desc: "刷新数据" },
                    { key: ":s", desc: "打开 / 关闭设置" },
                    { key: ":todo / :idea / :log", desc: "切换输入类型" },
                    { key: ":open", desc: "查看当前项" },
                    { key: ":e / :edit", desc: "编辑当前项" },
                    { key: ":d / :delete", desc: "删除当前项" },
                    { key: ":done / :archive / :reopen", desc: "待办状态操作" },
                    { key: ":help", desc: "显示本帮助" }
                ]

                delegate: ColumnLayout {
                    id: helpRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0

                    // 小节标题（modelData.section 存在时显示）
                    Text {
                        visible: !!helpRow.modelData.section
                        text: helpRow.modelData.section || ""
                        color: theme.subtext1
                        font.pixelSize: cfg.fontSmall
                        font.bold: true
                        Layout.fillWidth: true
                        Layout.topMargin: 8
                        Layout.bottomMargin: 2
                    }

                    // 条目行（modelData.key 存在时显示）
                    RowLayout {
                        visible: !!helpRow.modelData.key
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            text: helpRow.modelData.key || ""
                            color: theme.blue
                            font.pixelSize: cfg.fontSmall
                            font.bold: true
                            Layout.preferredWidth: 130
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: helpRow.modelData.desc || ""
                            color: theme.subtext0
                            font.pixelSize: cfg.fontSmall
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            // 分隔线
            Rectangle {
                Layout.fillWidth: true
                height: 1
                Layout.topMargin: 8
                color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
            }

            // ── 第二节：IPC 命令 ──
            Text {
                text: "IPC 命令"
                color: theme.subtext1
                font.pixelSize: cfg.fontSmall
                font.bold: true
                Layout.fillWidth: true
                Layout.topMargin: 4
            }

            Repeater {
                model: [
                    { key: "panel toggle", desc: "切换显隐" },
                    { key: "panel show",   desc: "显示面板" },
                    { key: "panel hide",   desc: "隐藏面板" }
                ]

                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "qs -c star-panel ipc call " + modelData.key
                        color: theme.blue
                        font.pixelSize: cfg.fontTiny
                        font.bold: true
                        Layout.preferredWidth: 200
                        Layout.alignment: Qt.AlignVCenter
                        wrapMode: Text.WrapAnywhere
                    }

                    Text {
                        text: modelData.desc
                        color: theme.subtext0
                        font.pixelSize: cfg.fontSmall
                        Layout.fillWidth: true
                    }
                }
            }

            // 底部提示
            Text {
                text: "🌟 溯星逆流追寻星渺"
                color: theme.overlay0
                font.pixelSize: cfg.fontTiny
                Layout.fillWidth: true
                Layout.topMargin: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }  // ColumnLayout
    }  // ScrollView (contentItem)
}
