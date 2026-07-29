import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/// QuickInput — 底部快速输入组件
/// Pipe 模式快速捕获灵感、待办、日志到 Starcatch
/// 支持 :command 模式（:q/:r/:s/:todo/:idea/:log/:help）
Item {
    id: root

    implicitHeight: logImageInputVisible ? 72 : 40
    property bool inputActive: textInput.activeFocus || logImageField.activeFocus
    property bool cmdMode: false
    readonly property bool logImageInputVisible: !cmdMode && typeSelector.typeModels[typeSelector.currentIndex].type === "log"

    // 供列表的 vim `o` 调用：聚焦输入框（进入 insert mode）
    function focusInput() { textInput.forceActiveFocus(); }

    // 供列表的 vim `:` 调用：进命令模式（设 ":" 自动触发 onTextChanged）
    function enterCommandMode() {
        textInput.text = ":";
        textInput.forceActiveFocus();
    }

    function splitImagePaths(text) {
        var raw = (text || "").split(/[\n,]/);
        var paths = [];
        for (var i = 0; i < raw.length; i++) {
            var path = raw[i].trim();
            if (path) paths.push(path);
        }
        return paths;
    }

    function parseLogInput(raw) {
        var text = (raw || "").trim();
        var sep = text.indexOf("|");
        if (sep >= 0) {
            var meta = parseLogTokens(text.slice(sep + 1), false);
            meta.content = text.slice(0, sep).trim();
            return meta;
        }
        return parseLogTokens(text, true);
    }

    function parseLogTokens(raw, collectContent) {
        var tokens = (raw || "").trim().split(/\s+/);
        var result = { content: collectContent ? "" : "", mood: "", tags: [], project: "" };
        var contentParts = [];
        for (var i = 0; i < tokens.length; i++) {
            var token = tokens[i];
            if (!token) continue;
            if (token.indexOf("mood:") === 0 || token.indexOf("mood：") === 0) {
                var mood = token.slice(5).trim();
                if (!mood && i + 1 < tokens.length) mood = tokens[++i];
                result.mood = mood;
            } else if (token.indexOf("project:") === 0 || token.indexOf("project：") === 0) {
                var project = token.slice(8).trim();
                if (!project && i + 1 < tokens.length) project = tokens[++i];
                result.project = project;
            } else if (token[0] === "#") {
                var tag = token.slice(1).replace(/[，,。.!?！？；;：:]+$/, "").trim();
                if (tag) result.tags.push(tag);
            } else if (collectContent) {
                contentParts.push(token);
            }
        }
        if (collectContent) result.content = contentParts.join(" ");
        return result;
    }

    function buildLogAddCommand(inputText, imageText) {
        var images = splitImagePaths(imageText);
        if (images.length === 0) return null;

        var parsed = parseLogInput(inputText);
        var content = (parsed.content || "").trim();
        if (!content) return { error: "内容不能为空" };

        var cmd = ["starcatch", "log", "add", content];
        if (parsed.mood) cmd.push("-m", parsed.mood);
        if (parsed.tags.length > 0) cmd.push("-t", parsed.tags.join(","));
        if (parsed.project) cmd.push("-P", parsed.project);
        for (var i = 0; i < images.length; i++) {
            cmd.push("--image", images[i]);
        }
        return { command: cmd };
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

    ClipboardImagePaste {
        id: clipboardImagePaste
        toastTarget: panel
        onImageCaptured: function(path) {
            logImageField.text = clipboardImagePaste.appendPath(logImageField.text, path);
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: theme ? Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.6) : "#313244"
        border.width: 1
        border.color: root.inputActive
            ? (theme ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.4) : Qt.rgba(0.54, 0.71, 0.98, 0.4))
            : (theme ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3) : Qt.rgba(0.27, 0.34, 0.38, 0.3))

        // ── 命令模式候选列表（显示在输入框上方） ──
        ColumnLayout {
            id: cmdPanel
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            anchors.left: parent.left
            anchors.right: parent.right
            visible: root.cmdMode
            spacing: 1

            property var allCommands: [
                { cmd: ":q",     desc: "关闭面板" },
                { cmd: ":r",     desc: "刷新数据" },
                { cmd: ":reload", desc: "刷新数据" },
                { cmd: ":s",     desc: "设置面板" },
                { cmd: ":todo",  desc: "切换为待办输入" },
                { cmd: ":idea",  desc: "切换为灵感输入" },
                { cmd: ":log",   desc: "切换为日志输入" },
                { cmd: ":open",  desc: "查看当前项" },
                { cmd: ":e",     desc: "编辑当前项" },
                { cmd: ":edit",  desc: "编辑当前项" },
                { cmd: ":d",     desc: "删除当前项" },
                { cmd: ":delete", desc: "删除当前项" },
                { cmd: ":y",     desc: "复制当前项到剪切板" },
                { cmd: ":copy",  desc: "复制当前项到剪切板" },
                { cmd: ":yank",  desc: "复制当前项到剪切板" },
                { cmd: ":done",  desc: "标记当前待办完成" },
                { cmd: ":archive", desc: "归档当前待办" },
                { cmd: ":reopen", desc: "恢复当前待办" },
                { cmd: ":help",  desc: "显示帮助" }
            ]
            property var candidates: allCommands
            property int selectedIndex: 0

            function filter(text) {
                // 取 ":" 之后、空格前的首段作为命令名，忽略后续参数；
                // 同时支持包含匹配（:a → :idea），更符合 vim 模糊回忆
                var raw = text.slice(1).split(" ")[0].toLowerCase();
                if (!raw) { candidates = allCommands; return; }
                candidates = allCommands.filter(function(c) {
                    return c.cmd.indexOf(raw, 1) >= 1;
                });
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.max(32, cmdList.count * 26 + 8)
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

                    Text {
                        visible: cmdPanel.candidates.length === 0
                        text: "无匹配命令"
                        color: theme.overlay0
                        font.pixelSize: cfg.fontSmall
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                Layout.leftMargin: 10
                Layout.rightMargin: 6
                spacing: 6

            // 模式徽章（vim 风格 INSERT/NORMAL/CMD）
            Text {
                text: root.cmdMode ? "⌨ CMD"
                    : (root.inputActive ? "✎ INSERT" : "▸ NORMAL")
                color: root.cmdMode ? (theme ? theme.blue : "#89b4fa")
                    : (root.inputActive ? (theme ? theme.green : "#a6e3a1")
                                        : (theme ? theme.overlay0 : "#6c7086"))
                font.pixelSize: cfg.fontTiny
                font.bold: true
                Layout.preferredWidth: 64
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            // 类型选择指示器
            Text {
                text: typeSelector.typeModels[typeSelector.currentIndex].icon
                font.pixelSize: cfg.fontMedium
                visible: !root.cmdMode
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

                // Tab 切换类型 / 切换命令候选；vim/emacs 文本编辑绑定
                Keys.onPressed: function(event) {
                    if (clipboardImagePaste.isPasteShortcut(event)) {
                        clipboardImagePaste.requestPaste(textInput, root.logImageInputVisible);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Tab) {
                        event.accepted = true;
                        var shift = event.modifiers & Qt.ShiftModifier;
                        if (root.cmdMode && cmdPanel.candidates.length > 0) {
                            var len = cmdPanel.candidates.length;
                            cmdPanel.selectedIndex = (cmdPanel.selectedIndex + (shift ? -1 : 1) + len) % len;
                        } else {
                            var tlen = typeSelector.typeModels.length;
                            typeSelector.currentIndex = (typeSelector.currentIndex + (shift ? -1 : 1) + tlen) % tlen;
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
                        panel.switchToEnglishIme();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape && !root.cmdMode) {
                        // vim: Esc 从 insert mode 返回 normal mode（列表）
                        textInput.text = "";
                        panel.focusCurrentList();
                        panel.switchToEnglishIme();
                        event.accepted = true;
                    } else if (panel.handleEmacsEdit(textInput, event)) {
                        return;
                    }
                }

                function executeCommand(cmd) {
                    // 统一取冒号后、空格前的首段作为命令名，忽略参数
                    var name = cmd.split(" ")[0];
                    switch (name) {
                        case ":q":    panel.panelVisible = false; break;
                        case ":r":
                        case ":reload":
                            panel.reloadData();
                            panel.showToast("🔄 刷新中...");
                            break;
                        case ":s":
                            if (settingsPanel.visible) settingsPanel.close();
                            else settingsPanel.open();
                            textInput.text = "";
                            root.cmdMode = false;
                            return;
                        case ":todo": typeSelector.currentIndex = 0; break;
                        case ":idea": typeSelector.currentIndex = 1; break;
                        case ":log":  typeSelector.currentIndex = 2; break;
                        case ":open":
                            panel.openCurrentItem();
                            break;
                        case ":e":
                        case ":edit":
                            panel.editCurrentItem();
                            break;
                        case ":d":
                        case ":delete":
                            panel.deleteCurrentItem();
                            break;
                        case ":y":
                        case ":copy":
                        case ":yank":
                            panel.copyCurrentItem();
                            break;
                        case ":done":
                            panel.runCurrentTodoAction("done");
                            break;
                        case ":archive":
                            panel.runCurrentTodoAction("archive");
                            break;
                        case ":reopen":
                            panel.runCurrentTodoAction("reopen");
                            break;
                        case ":help":
                            panel.openHelp();
                            textInput.text = "";
                            root.cmdMode = false;
                            return;
                        default:
                            panel.showToast("⚠️ 未知命令 " + name + " · :help 查看全部");
                            textInput.text = "";
                            root.cmdMode = false;
                            textInput.forceActiveFocus();
                            return;
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

                function submit() {
                    if (root.cmdMode) {
                        if (cmdPanel.candidates.length === 0) {
                            panel.showToast("⚠️ 未知命令 · :help 查看全部");
                            textInput.text = "";
                            root.cmdMode = false;
                            return;
                        }
                        executeSelected();
                        return;
                    }
                    var inputText = textInput.text.trim();
                    if (inputText === "") return;
                    if (pipeProc.running) {
                        panel.showToast("⏳ 捕获中...");
                        return;
                    }

                    if (inputText[0] === ":") {
                        executeCommand(inputText.split(" ")[0]);
                        return;
                    }

                    var type = typeSelector.typeModels[typeSelector.currentIndex].type;

                    pipeProc.pendingType = type;
                    pipeProc.pendingText = inputText;
                    pipeProc.pendingImages = type === "log" ? logImageField.text : "";

                    var logCommand = type === "log" ? root.buildLogAddCommand(inputText, logImageField.text) : null;
                    if (logCommand && logCommand.error) {
                        panel.showToast("⚠️ " + logCommand.error);
                        return;
                    }

                    if (logCommand && logCommand.command) {
                        pipeProc.command = logCommand.command;
                    } else {
                        var safeText = "'" + inputText.replace(/'/g, "'\\''") + "'";
                        pipeProc.command = ["bash", "-c", "printf '%s\\n' " + safeText + " | starcatch pipe " + type];
                    }
                    pipeProc.running = true;

                    textInput.text = "";
                    if (type === "log") logImageField.text = "";
                    textInput.forceActiveFocus();
                }

                Keys.onReturnPressed: submit()
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

                // Tab / 点击 / :todo|:idea|:log 改类型时，主面板待办/灵感/日志跟着切
                onCurrentIndexChanged: panel.setMainTab(currentIndex)

                function indexFromType(type) {
                    for (var i = 0; i < typeModels.length; i++) {
                        if (typeModels[i].type === type) return i;
                    }
                    return 0;
                }

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

            RowLayout {
                id: imageRow
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                Layout.leftMargin: 10
                Layout.rightMargin: 6
                spacing: 6
                visible: root.logImageInputVisible

                Text {
                    text: "📎"
                    color: theme ? theme.overlay0 : "#6c7086"
                    font.pixelSize: cfg.fontSmall
                    Layout.preferredWidth: 64
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                TextField {
                    id: logImageField
                    Layout.fillWidth: true
                    color: theme ? theme.text : "#cdd6f4"
                    placeholderTextColor: theme ? theme.overlay0 : "#6c7086"
                    placeholderText: "图片路径，或 Ctrl+V 粘贴图片"
                    font.pixelSize: cfg.fontSmall
                    verticalAlignment: Text.AlignVCenter
                    background: null
                    onAccepted: textInput.submit()
                    Keys.onPressed: function(event) {
                        if (clipboardImagePaste.isPasteShortcut(event)) {
                            clipboardImagePaste.requestPaste(logImageField, true);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Escape) {
                            if (logImageField.text !== "") {
                                clipboardImagePaste.cleanupAll();
                                logImageField.text = "";
                            } else {
                                textInput.forceActiveFocus();
                            }
                            panel.switchToEnglishIme();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Tab) {
                            textInput.forceActiveFocus();
                            event.accepted = true;
                        } else {
                            panel.handleEmacsEdit(logImageField, event);
                        }
                    }
                }

                Button {
                    flat: true
                    visible: logImageField.text !== ""
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    onClicked: {
                        clipboardImagePaste.cleanupAll();
                        logImageField.text = "";
                    }
                    contentItem: Text {
                        text: "✕"
                        color: theme ? theme.overlay0 : "#6c7086"
                        font.pixelSize: cfg.fontTiny
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered && theme
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                            : "transparent"
                    }
                }
            }
        }

        // pipe 写入 Process：写入完成后再刷新对应列表，避免读到写入前的旧数据；
        // 失败时通过 panel 的 toast 给用户反馈。
        Process {
            id: pipeProc
            running: false
            property string pendingType: ""
            property string pendingText: ""
            property string pendingImages: ""
            stdout: StdioCollector {}
            stderr: StdioCollector { id: pipeStderr }
            onExited: function(exitCode, exitStatus) {
                if (exitCode !== 0) {
                    var detail = pipeStderr.text.trim();
                    panel.showToast("❌ 捕获失败" + (detail ? "：" + detail.split("\n")[0] : "（退出码 " + exitCode + "）"));
                    textInput.text = pendingText;
                    logImageField.text = pendingImages;
                    typeSelector.currentIndex = typeSelector.indexFromType(pendingType);
                    root.cmdMode = false;
                    textInput.forceActiveFocus();
                } else {
                    if (pendingType === "log") clipboardImagePaste.cleanupAll();
                    panel.showToast("✨ 已捕获");
                    if (pendingType) panel.reloadData(pendingType);
                }
                pendingType = "";
                pendingText = "";
                pendingImages = "";
            }
        }
    }
}
