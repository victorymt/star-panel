import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// QuickInput — 底部快速输入组件
/// Pipe 模式快速捕获灵感、待办、日志到 Starcatch
/// 支持 :command 模式（:q/:r/:s/:todo/:idea/:log/:help）
Item {
    id: root

    implicitHeight: 40
    property alias inputActive: textInput.activeFocus
    property bool cmdMode: false
    property bool helpVisible: false

    Timer {
        id: helpTimer
        interval: 2500
        repeat: false
        onTriggered: root.helpVisible = false
    }

    // 面板打开时延迟聚焦，配合滑入动画
    Connections {
        target: panel
        function onPanelVisibleChanged() {
            if (panel.panelVisible) {
                focusTimer.start();
            }
        }
    }

    Timer {
        id: focusTimer
        interval: cfg.animationDuration
        repeat: false
        onTriggered: textInput.forceActiveFocus()
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: theme ? Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.6) : "#313244"
        border.width: 1
        border.color: textInput.activeFocus
            ? (theme ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.4) : Qt.rgba(0.54, 0.71, 0.98, 0.4))
            : (theme ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3) : Qt.rgba(0.27, 0.34, 0.38, 0.3))

        // ── 命令模式候选列表（显示在输入框上方） ──
        ColumnLayout {
            id: cmdPanel
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            visible: (root.cmdMode || root.helpVisible) && candidates.length > 0
            spacing: 1

            property var allCommands: [
                { cmd: ":q",     desc: "关闭面板" },
                { cmd: ":r",     desc: "刷新数据" },
                { cmd: ":s",     desc: "设置面板" },
                { cmd: ":todo",  desc: "切换为待办输入" },
                { cmd: ":idea",  desc: "切换为灵感输入" },
                { cmd: ":log",   desc: "切换为日志输入" },
                { cmd: ":help",  desc: "显示帮助" }
            ]
            property var candidates: allCommands
            property int selectedIndex: 0

            function filter(text) {
                var raw = text.slice(1).toLowerCase();
                if (!raw) { candidates = allCommands; return; }
                candidates = allCommands.filter(function(c) {
                    return c.cmd.indexOf(raw) === 1;
                });
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: cmdList.count * 26 + 8
                radius: 8
                color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.95)
                border.width: 1
                border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 1
                    Repeater {
                        id: cmdList
                        model: cmdPanel.candidates

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            height: 24
                            radius: 4
                            color: index === cmdPanel.selectedIndex
                                ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.25)
                                : "transparent"

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                Text {
                                    text: modelData.cmd
                                    color: index === cmdPanel.selectedIndex ? theme.blue : theme.text
                                    font.pixelSize: cfg.fontSmall
                                    font.bold: true
                                }
                                Text {
                                    text: modelData.desc
                                    color: theme.overlay0
                                    font.pixelSize: cfg.fontTiny
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    cmdPanel.selectedIndex = index;
                                    textInput.executeCommand(modelData.cmd);
                                }
                            }
                        }
                    }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 6
            spacing: 6

            // 类型选择指示器
            Text {
                text: root.cmdMode ? "⌨" : typeSelector.typeModels[typeSelector.currentIndex].icon
                font.pixelSize: cfg.fontMedium
            }

            // 快速输入框
            TextField {
                id: textInput
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
                color: theme ? theme.text : "#cdd6f4"
                placeholderTextColor: theme ? theme.overlay0 : "#6c7086"
                placeholderText: root.cmdMode ? ": 输入命令... (:help 查看全部)" : "快速捕获...  Tab切换 Enter提交"
                font.pixelSize: cfg.fontBase
                clip: true
                activeFocusOnPress: true
                background: null

                property string rawText: ""

                onTextChanged: {
                    rawText = text;
                    if (text === ":") {
                        root.cmdMode = true;
                        cmdPanel.selectedIndex = 0;
                        cmdPanel.filter(":");
                    } else if (root.cmdMode) {
                        if (text.length > 0 && text[0] === ":") {
                            cmdPanel.filter(text);
                            cmdPanel.selectedIndex = 0;
                            if (cmdPanel.selectedIndex >= cmdPanel.candidates.length) {
                                cmdPanel.selectedIndex = cmdPanel.candidates.length - 1;
                            }
                        } else {
                            root.cmdMode = false;
                        }
                    }
                }

                // Tab 切换类型 / 切换命令候选
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Tab) {
                        event.accepted = true;
                        if (root.cmdMode && cmdPanel.candidates.length > 0) {
                            cmdPanel.selectedIndex = (cmdPanel.selectedIndex + 1) % cmdPanel.candidates.length;
                        } else {
                            typeSelector.currentIndex = (typeSelector.currentIndex + 1) % typeSelector.typeModels.length;
                        }
                    } else if (event.key === Qt.Key_Down && root.cmdMode) {
                        cmdPanel.selectedIndex = Math.min(cmdPanel.selectedIndex + 1, cmdPanel.candidates.length - 1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Up && root.cmdMode) {
                        cmdPanel.selectedIndex = Math.max(cmdPanel.selectedIndex - 1, 0);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape && root.cmdMode) {
                        textInput.text = "";
                        root.cmdMode = false;
                        event.accepted = true;
                    }
                }

                function executeCommand(cmd) {
                    switch (cmd) {
                        case ":q":    panel.panelVisible = false; break;
                        case ":r":    panel.reloadData(); break;
                        case ":s":    settingsPanel.visible ? settingsPanel.close() : settingsPanel.open(); break;
                        case ":todo": typeSelector.currentIndex = 0; break;
                        case ":idea": typeSelector.currentIndex = 1; break;
                        case ":log":  typeSelector.currentIndex = 2; break;
                        case ":help": root.helpVisible = true; helpTimer.start(); break;
                    }
                    textInput.text = "";
                    root.cmdMode = false;
                    textInput.forceActiveFocus();
                }

                function executeSelected() {
                    if (cmdPanel.selectedIndex >= 0 && cmdPanel.selectedIndex < cmdPanel.candidates.length) {
                        executeCommand(cmdPanel.candidates[cmdPanel.selectedIndex].cmd);
                    }
                }

                Keys.onReturnPressed: {
                    if (root.cmdMode) {
                        executeSelected();
                        return;
                    }
                    var inputText = textInput.text.trim();
                    if (inputText === "") return;

                    if (inputText[0] === ":") {
                        executeCommand(inputText.split(" ")[0]);
                        return;
                    }

                    var type = typeSelector.typeModels[typeSelector.currentIndex].type;
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
                property var typeModels: [
                    { type: "todo", label: "📋 待办", icon: "📋" },
                    { type: "idea", label: "💭 灵感", icon: "💭" },
                    { type: "log",  label: "📓 日志", icon: "📓" }
                ]
                property int currentIndex: 0

                contentItem: Text {
                    text: typeSelector.typeModels[typeSelector.currentIndex].label
                    color: theme ? theme.subtext0 : "#a6adc8"
                    font.pixelSize: cfg.fontSmall
                }

                flat: true
                onClicked: {
                    typeSelector.currentIndex = (typeSelector.currentIndex + 1) % typeSelector.typeModels.length;
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
