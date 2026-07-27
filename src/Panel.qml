import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

/// StarPanel — 负一屏主窗口
/// 从右侧滑出，展示 Starcatch 的三类数据：Todo / Idea / Log
PanelWindow {
    id: panel

    // ── Wayland 属性 ──
    WlrLayershell.namespace: "qs-star-panel"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    focusable: true

    // ── 尺寸与定位 ──
    readonly property real panelWidth: cfg.panelWidth
    readonly property real panelMargin: cfg.panelMargin

    // 窗口铺满屏幕宽度（透明背景，exclusionMode: Ignore 不占空间），
    // 这样点击面板左侧空白区才能被 MouseArea 捕获 → 关闭面板。
    implicitWidth: screen.width
    implicitHeight: screen.height
    color: "transparent"

    // PanelWindow.anchors 将窗口贴附到屏幕边缘（布尔值，非 Qt Item.anchors）
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true

    // ── 公开刷新接口（供子组件调用） ──
    function reloadData(type) {
        dataFetcher.reload(type);
    }

    // ── 通用 toast 反馈（供子组件调用） ──
    function showToast(msg) {
        toastLabel.text = msg;
        toast.show();
    }

    // ── 打开帮助面板（供 QuickInput 的 :help 命令调用） ──
    function openHelp() {
        helpPanel.open();
    }

    // ── 关闭最顶层弹窗或面板本身（Esc / q / Ctrl+Q 共用） ──
    // 优先级：help → settings → edit/detail 弹窗 → 面板
    function closeTopOrSelf() {
        if (helpPanel.visible)                 helpPanel.close();
        else if (settingsPanel.visible)        settingsPanel.close();
        else if (todoList.editPopup.visible)   todoList.editPopup.close();
        else if (ideaList.editPopup.visible)   ideaList.editPopup.close();
        else if (logList.editPopup.visible)    logList.editPopup.close();
        else if (todoList.detailPopup.visible) todoList.detailPopup.close();
        else if (ideaList.detailPopup.visible) ideaList.detailPopup.close();
        else if (logList.detailPopup.visible)  logList.detailPopup.close();
        else                                   panelVisible = false;
    }

    // ── 切换 tab（vim h/l 用） ──
    function switchTab(delta) {
        var len = tabBar.tabs.length;
        tabBar.currentIndex = (tabBar.currentIndex + delta + len) % len;
        focusCurrentList();
    }

    // 仅切换主面板 tab，不抢焦点（供快速输入 Tab 切类型时联动）
    function setMainTab(index) {
        if (index < 0 || index >= tabBar.tabs.length) return;
        if (tabBar.currentIndex !== index)
            tabBar.currentIndex = index;
    }

    // ── 聚焦当前 tab 的列表（vim normal mode 入口） ──
    function focusCurrentList() {
        if (tabBar.currentIndex === 0) todoList.focusList();
        else if (tabBar.currentIndex === 1) ideaList.focusList();
        else logList.focusList();
    }

    function currentList() {
        if (tabBar.currentIndex === 0) return todoList;
        if (tabBar.currentIndex === 1) return ideaList;
        return logList;
    }

    function openCurrentItem() {
        currentList().openCurrentItem();
    }

    function editCurrentItem() {
        currentList().editCurrentItem();
    }

    function deleteCurrentItem() {
        currentList().deleteCurrentItem();
    }

    // ── 复制到剪切板（vim y / :y） ──
    function copyText(text) {
        var t = (text || "").toString();
        if (!t) {
            showToast("📭 没有可复制的内容");
            return false;
        }
        Quickshell.clipboardText = t;
        showToast("📋 已复制到剪切板");
        return true;
    }

    function formatCopyText(type, item) {
        if (!item) return "";
        if (type === "idea") {
            var title = (item.title || "").toString().trim();
            var content = (item.content || "").toString().trim();
            if (title && content && content !== title) return title + "\n" + content;
            return title || content;
        }
        if (type === "log") {
            return (item.content || "").toString().trim();
        }
        // todo：标题 + 描述
        var t = (item.title || "").toString().trim();
        var d = (item.description || "").toString().trim();
        if (t && d) return t + "\n" + d;
        return t || d;
    }

    function copyItem(type, item) {
        return copyText(formatCopyText(type, item));
    }

    function copyCurrentItem() {
        var list = currentList();
        if (list && list.copyCurrentItem) list.copyCurrentItem();
        else showToast("📭 列表为空");
    }

    function runCurrentTodoAction(cmd) {
        if (tabBar.currentIndex !== 0) {
            showToast("⚠️ 该命令只适用于待办");
            return;
        }
        todoList.runTodoAction(cmd);
    }

    function handleEmacsEdit(field, event) {
        if (!(event.modifiers & Qt.ControlModifier)) return false;
        if (event.key === Qt.Key_A) {
            field.cursorPosition = 0;
        } else if (event.key === Qt.Key_E) {
            field.cursorPosition = field.text.length;
        } else if (event.key === Qt.Key_B) {
            field.cursorPosition = Math.max(0, field.cursorPosition - 1);
        } else if (event.key === Qt.Key_F) {
            field.cursorPosition = Math.min(field.text.length, field.cursorPosition + 1);
        } else if (event.key === Qt.Key_K) {
            var pos = field.cursorPosition;
            var end = field.text.indexOf("\n", pos);
            field.text = end >= 0
                ? field.text.slice(0, pos) + field.text.slice(end)
                : field.text.slice(0, pos);
            field.cursorPosition = pos;
        } else if (event.key === Qt.Key_U) {
            field.text = "";
            field.cursorPosition = 0;
        } else {
            return false;
        }
        event.accepted = true;
        return true;
    }

    // 从编辑/输入态按 Esc 退出时，把 fcitx5+rime 切到英文（ascii_mode）。
    // 保持 rime 引擎，与 Ctrl+Space 中英语义一致；fcitx 未运行时静默失败。
    function switchToEnglishIme() {
        Quickshell.execDetached([
            "busctl", "--user", "call",
            "org.fcitx.Fcitx5", "/rime",
            "org.fcitx.Fcitx.Rime1", "SetAsciiMode", "b", "true"
        ]);
    }

    // ── 删除项（vim dd 用） ──
    function deleteItem(type, id, onSuccess) {
        if (!id) { showToast("⚠️ 该项没有 id，无法删除"); return; }
        if (deleteProc.running) { showToast("⏳ 删除中..."); return; }
        deleteProc.pendingType = type;
        deleteProc.onSuccess = onSuccess || null;
        deleteProc.command = ["starcatch", type, "delete", id];
        deleteProc.running = true;
    }

    // ── 相对日期转换（供子组件调用） ──
    function dateDiffDays(due) {
        if (!due || due === "-") return null;
        var today = new Date();
        today.setHours(0, 0, 0, 0);
        var parts = due.split("-");
        var d = new Date(parseInt(parts[0], 10), parseInt(parts[1], 10) - 1, parseInt(parts[2], 10));
        return Math.round((d - today) / (1000 * 60 * 60 * 24));
    }

    function getDueText(due) {
        var diff = dateDiffDays(due);
        if (diff === null) return "";
        if (diff === 0) return "🔥 今天";
        if (diff === 1) return "📅 明天";
        if (diff === 2) return "📅 后天";
        if (diff < 0) return "⚠️ " + due.slice(5);
        return due.slice(5);
    }

    function getDueColor(due, clr) {
        var diff = dateDiffDays(due);
        if (diff === null) return "transparent";
        if (diff < 0) return clr ? clr.red : "#f38ba8";
        if (diff < 2) return clr ? clr.peach : "#fab387";
        return clr ? clr.overlay0 : "#6c7086";
    }

    function getDueDisplay(due) {
        if (!due || due === "-") return "";
        var diff = dateDiffDays(due);
        if (diff === null) return "";
        var dateStr = due.slice(5);
        if (diff === 0) return dateStr + " (🔥 今天)";
        if (diff === 1) return dateStr + " (📅 明天)";
        if (diff === 2) return dateStr + " (📅 后天)";
        if (diff < 0) return dateStr + " (⚠️ 已过期 " + Math.abs(diff) + " 天)";
        return dateStr;
    }

    // ── 配置 & 主题色 ──
    Colors { id: theme }
    Config { id: cfg }

    // ── 主题预设应用 ──
    Connections {
        target: cfg
        function onThemeNameChanged() {
            if (cfg.themeName !== "") {
                theme.applyPreset(cfg.themeName);
                theme.stopPolling();
            } else {
                theme.reloadMatugen();
                theme.startPolling();
            }
        }
    }

    // ── 显隐控制 ──
    // slideOffset: 0 = 显示；panelWidth + panelMargin = 隐藏（backdrop 滑出屏幕右边）
    property bool panelVisible: false
    property real slideOffset: panelWidth + panelMargin
    Behavior on slideOffset {
        NumberAnimation {
            duration: cfg.animationDuration
            easing.type: Easing.OutQuint
        }
    }

    visible: panelVisible || slideOffset < panelWidth + panelMargin

    onPanelVisibleChanged: {
        slideOffset = panelVisible ? 0 : (panelWidth + panelMargin);
        if (panelVisible) {
            autoRefreshTimer.start();
            // 显示时立即刷新一次，避免长时间隐藏后看到过期数据
            dataFetcher.reload();
        } else {
            autoRefreshTimer.stop();
        }
    }

    // 宽度变化时更新隐藏位置，防止面板异常显示
    onPanelWidthChanged: {
        if (!panelVisible) {
            slideOffset = panelWidth + panelMargin;
        }
    }

    Component.onCompleted: {
        slideOffset = panelWidth + panelMargin;
        // 主题初始化由 Config.settingsLoader 完成后调用 theme.initFromSettings()，
        // 避免启动时 matugen 色闪现后才套用预设。
        Qt.callLater(() => dataFetcher.reload());
    }

    // ── IPC 控制 ──
    IpcHandler {
        target: "panel"

        function toggle() {
            panel.panelVisible = !panel.panelVisible;
        }

        function show() {
            panel.panelVisible = true;
        }

        function hide() {
            panel.panelVisible = false;
        }
    }

    // ── 点击外部关闭（必须在 backdrop 之前，否则拦截所有事件） ──
    MouseArea {
        anchors.fill: parent
        enabled: panelVisible
        onClicked: {
            if (mouse.x < backdrop.x || mouse.x > backdrop.x + backdrop.width) {
                panelVisible = false;
            }
        }
    }

    // ── 背景面板（靠右） ──
    Rectangle {
        id: backdrop
        x: parent.width - panelWidth - panelMargin + slideOffset
        y: panelMargin
        width: panelWidth
        height: parent.height - panelMargin * 2
        radius: cfg.panelRadius

        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.92)
        border.width: 1
        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)

        // ── 内容区域 ──
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ── 头部 ──
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "⭐ 星捕"
                    color: theme.text
                    font.pixelSize: cfg.fontXl
                    font.bold: true
                }

                Item { Layout.fillWidth: true }

                Button {
                    flat: true
                    onClicked: dataFetcher.reload()
                    contentItem: Text {
                        text: "↻"
                        color: theme.subtext0
                        font.pixelSize: cfg.fontLarge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.6)
                            : "transparent"
                    }
                }

                Button {
                    flat: true
                    onClicked: settingsPanel.open()
                    contentItem: Text {
                        text: "⚙"
                        color: theme.subtext0
                        font.pixelSize: cfg.fontLarge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.6)
                            : "transparent"
                    }
                }

                Button {
                    flat: true
                    onClicked: panel.panelVisible = false
                    contentItem: Text {
                        text: "✕"
                        color: theme.subtext0
                        font.pixelSize: cfg.fontLarge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.2)
                            : "transparent"
                    }
                }
            }

            // ── 选项卡 ──
            RowLayout {
                id: tabBar
                Layout.fillWidth: true
                spacing: 4
                property int currentIndex: cfg.defaultTab

                property var tabs: [
                    { label: "📋 待办" },
                    { label: "💭 灵感" },
                    { label: "📓 日志" }
                ]

                Repeater {
                    model: tabBar.tabs

                    delegate: Button {
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        flat: true
                        onClicked: tabBar.currentIndex = index

                        contentItem: Text {
                            text: modelData.label
                            color: tabBar.currentIndex === index ? theme.text : theme.overlay0
                            font.pixelSize: cfg.fontBase
                            font.bold: tabBar.currentIndex === index
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        background: Rectangle {
                            radius: 8
                            color: tabBar.currentIndex === index
                                ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                                : "transparent"
                        }

                        ToolTip {
                            text: "Ctrl+" + (index + 1)
                            visible: parent.hovered
                            delay: 500
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
            }

            // ── 数据获取器 ──
            Item {
                id: dataFetcher

                property var todos: []
                property var ideas: []
                property var logs: []
                property bool loading: false
                property int pendingCount: 0
                property string queuedReloadType: ""
                // 三个独立 error 属性，避免并行 Process 互相覆盖；
                // 聚合 error 只读属性供 UI 显示（优先 todo → idea → log）。
                property string todoError: ""
                property string ideaError: ""
                property string logError: ""
                property string timeoutError: ""
                readonly property string error: todoError || ideaError || logError || timeoutError

                function reload(type) {
                    var normalized = normalizeReloadType(type);
                    if (pendingCount > 0) {
                        queueReload(normalized);
                        return;
                    }
                    startReload(normalized);
                }

                function startReload(type) {
                    loading = true;
                    timeoutError = "";
                    pendingCount = 0;

                    if (type === "todo") {
                        todoError = "";
                        fetchTodos();
                    } else if (type === "idea") {
                        ideaError = "";
                        fetchIdeas();
                    } else if (type === "log") {
                        logError = "";
                        fetchLogs();
                    } else {
                        todoError = "";
                        ideaError = "";
                        logError = "";
                        fetchTodos();
                        fetchIdeas();
                        fetchLogs();
                    }

                    if (pendingCount > 0) {
                        fetchTimeout.restart();
                    } else {
                        loading = false;
                        fetchTimeout.stop();
                    }
                }

                function normalizeReloadType(type) {
                    if (type === "todo" || type === "idea" || type === "log") return type;
                    return "all";
                }

                function queueReload(type) {
                    var next = normalizeReloadType(type);
                    if (queuedReloadType === "") {
                        queuedReloadType = next;
                    } else if (queuedReloadType !== next) {
                        queuedReloadType = "all";
                    }
                }

                function drainQueuedReload() {
                    if (queuedReloadType === "") return;
                    var next = queuedReloadType;
                    queuedReloadType = "";
                    startReload(next);
                }

                function fetchTodos() {
                    pendingCount++;
                    todoProcess.running = true;
                }

                function fetchIdeas() {
                    pendingCount++;
                    ideaProcess.running = true;
                }

                function fetchLogs() {
                    pendingCount++;
                    logProcess.running = true;
                }

                function firstLine(text) {
                    var trimmed = (text || "").trim();
                    return trimmed ? trimmed.split("\n")[0] : "";
                }

                function parseListJson(text) {
                    var value = JSON.parse((text || "").trim());
                    if (!Array.isArray(value)) {
                        throw new Error("expected JSON array");
                    }
                    return value;
                }

                function emptyMessage(type) {
                    if (type === "todo") return "待办数据为空，请确认 Starcatch 可用";
                    if (type === "idea") return "灵感数据为空，请确认 Starcatch 可用";
                    return "日志数据为空，请确认 Starcatch 可用";
                }

                function failureMessage(type, exitCode, stderrText) {
                    var detail = firstLine(stderrText);
                    var prefix = type === "todo" ? "待办获取失败"
                        : type === "idea" ? "灵感获取失败"
                        : "日志获取失败";
                    return prefix + (detail ? "：" + detail : "（退出码 " + exitCode + "）");
                }

                function parseFailureMessage(type, err) {
                    var prefix = type === "todo" ? "待办解析失败"
                        : type === "idea" ? "灵感解析失败"
                        : "日志解析失败";
                    return prefix + "：" + err.message;
                }

                function setFetchError(type, msg) {
                    if (type === "todo") todoError = msg;
                    else if (type === "idea") ideaError = msg;
                    else logError = msg;
                }

                function setFetchItems(type, value) {
                    if (type === "todo") todos = value;
                    else if (type === "idea") ideas = value;
                    else logs = value;
                }

                function handleFetchDone(type, exitCode, stdoutText, stderrText) {
                    var out = (stdoutText || "").trim();

                    if (exitCode !== 0) {
                        setFetchError(type, failureMessage(type, exitCode, stderrText));
                        checkDone();
                        return;
                    }

                    if (!out) {
                        setFetchError(type, emptyMessage(type));
                        setFetchItems(type, []);
                        checkDone();
                        return;
                    }

                    try {
                        var raw = parseListJson(out);
                        if (type === "todo") setFetchItems(type, mapTodos(raw));
                        else if (type === "idea") setFetchItems(type, mapIdeas(raw));
                        else setFetchItems(type, mapLogs(raw));
                        setFetchError(type, "");
                    } catch (e) {
                        setFetchError(type, parseFailureMessage(type, e));
                    }

                    checkDone();
                }

                Process {
                    id: todoProcess
                    command: ["starcatch", "--json", "todo", "list", "--all"]
                    running: false
                    stdout: StdioCollector { id: todoStdout }
                    stderr: StdioCollector { id: todoStderr }
                    onExited: function(exitCode, exitStatus) {
                        dataFetcher.handleFetchDone("todo", exitCode, todoStdout.text, todoStderr.text);
                    }
                }

                Process {
                    id: ideaProcess
                    command: ["starcatch", "--json", "idea", "list", "-d", "7"]
                    running: false
                    stdout: StdioCollector { id: ideaStdout }
                    stderr: StdioCollector { id: ideaStderr }
                    onExited: function(exitCode, exitStatus) {
                        dataFetcher.handleFetchDone("idea", exitCode, ideaStdout.text, ideaStderr.text);
                    }
                }

                Process {
                    id: logProcess
                    command: ["starcatch", "--json", "log", "list", "-d", "3"]
                    running: false
                    stdout: StdioCollector { id: logStdout }
                    stderr: StdioCollector { id: logStderr }
                    onExited: function(exitCode, exitStatus) {
                        dataFetcher.handleFetchDone("log", exitCode, logStdout.text, logStderr.text);
                    }
                }

                function checkDone() {
                    pendingCount--;
                    if (pendingCount <= 0) {
                        pendingCount = 0;
                        loading = false;
                        fetchTimeout.stop();
                        drainQueuedReload();
                    }
                }

                Timer {
                    id: fetchTimeout
                    interval: 15000
                    repeat: false
                    onTriggered: {
                        if (dataFetcher.loading) {
                            dataFetcher.loading = false;
                            dataFetcher.timeoutError = "数据获取超时，请检查 Starcatch 是否运行";
                        }
                    }
                }

                // 自动刷新（面板可见期间 30s 循环）
                Timer {
                    id: autoRefreshTimer
                    interval: 30000
                    repeat: true
                    onTriggered: {
                        if (panel.panelVisible) dataFetcher.reload();
                    }
                }

                // ── JSON 解析辅助 ──
                function parseJson(text) {
                    try { return JSON.parse(text.trim()); } catch(e) { return []; }
                }

                function formatDate(iso) {
                    if (!iso) return "";
                    var parts = iso.split("T");
                    if (parts.length < 2) return parts[0] || "";
                    return parts[0].slice(5) + " " + parts[1].slice(0, 5);
                }

                // ── Todo JSON 映射 ──
                function mapTodos(raw) {
                    var priorityIcon = { "P0": "🔴", "P1": "🟡", "P2": "🟢", "P3": "⚪" };
                    var statusIcon = { "Pending": "⬜", "Done": "✅", "Archived": "📦" };
                    return raw.map(function(item) {
                        return {
                            id: item.id,
                            rawStatus: item.status,
                            priority: priorityIcon[item.priority] || "🟢",
                            status: statusIcon[item.status] || "⬜",
                            title: item.title,
                            description: item.description || "",
                            tags: item.tags || [],
                            due: item.due_date || "-"
                        };
                    });
                }

                function parseTodos(text) {
                    return mapTodos(parseJson(text));
                }

                // ── Idea JSON 映射 ──
                function mapIdeas(raw) {
                    return raw.map(function(item) {
                        var time = formatDate(item.created_at);
                        var subtitle = item.source ? "from: " + item.source + " · " + time : time;
                        return {
                            id: item.id,
                            title: item.title,
                            content: item.content || subtitle,
                            tags: item.tags || [],
                            time: time,
                            source: item.source || "?"
                        };
                    });
                }

                function parseIdeas(text) {
                    return mapIdeas(parseJson(text));
                }

                // ── Log JSON 映射 ──
                function mapLogs(raw) {
                    return raw.map(function(item) {
                        var time = formatDate(item.created_at);
                        return {
                            id: item.id,
                            title: time + (item.mood ? " · " + item.mood : ""),
                            content: item.content,
                            tags: item.tags || [],
                            images: item.images || [],
                            time: time
                        };
                    });
                }

                function parseLogs(text) {
                    return mapLogs(parseJson(text));
                }
            }

            // ── 错误提示 ──
            Rectangle {
                Layout.fillWidth: true
                visible: dataFetcher.error !== ""
                height: visible ? errorText.implicitHeight + 12 : 0
                radius: 6
                color: Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.12)
                Text {
                    id: errorText
                    anchors.fill: parent
                    anchors.margins: 6
                    text: dataFetcher.error
                    color: theme.red
                    font.pixelSize: cfg.fontSmall
                    wrapMode: Text.WordWrap
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // ── 内容区域 ──
            StackLayout {
                id: tabContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex

                TodoList { id: todoList; items: dataFetcher.todos; loading: dataFetcher.loading }
                IdeaList { id: ideaList; items: dataFetcher.ideas; loading: dataFetcher.loading }
                LogList  { id: logList;  items: dataFetcher.logs;  loading: dataFetcher.loading }
            }

            // ── 底部快速输入 ──
            QuickInput {
                id: quickInput
                Layout.fillWidth: true
                Layout.bottomMargin: 4
            }
        }

        // ── 设置面板 ──
        SettingsPanel { id: settingsPanel }

        // ── 帮助面板 ──
        HelpPanel { id: helpPanel }
    }

    // ── 快捷键 ──
    // Escape：优先关闭可见的详情弹窗（Quickshell 下 Popup 拿不到焦点，
    // CloseOnEscape 不可靠，故由全局 Shortcut 兜底）；其次关面板。
    // 快速输入 / 搜索框聚焦时让它们自己处理 Esc（窗口级 Shortcut 会抢先
    // 消费 Esc，导致 TextField 的 Keys.onPressed 收不到）。
    Shortcut {
        sequence: "Escape"
        enabled: panelVisible && !quickInput.inputActive
            && !todoList.searchActive && !ideaList.searchActive && !logList.searchActive
        onActivated: panel.closeTopOrSelf()
    }

    Shortcut { sequence: "Ctrl+1"; enabled: panelVisible; onActivated: tabBar.currentIndex = 0 }
    Shortcut { sequence: "Ctrl+2"; enabled: panelVisible; onActivated: tabBar.currentIndex = 1 }
    Shortcut { sequence: "Ctrl+3"; enabled: panelVisible; onActivated: tabBar.currentIndex = 2 }

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: panelVisible
        onActivated: tabBar.currentIndex = (tabBar.currentIndex + 1) % tabBar.tabs.length
    }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: panelVisible
        onActivated: tabBar.currentIndex = (tabBar.currentIndex - 1 + tabBar.tabs.length) % tabBar.tabs.length
    }

    // ── 搜索快捷 ──
    // 注意：当任一列表搜索框聚焦时禁用，避免在搜索框里打 "/" 被全局拦截
    Shortcut {
        sequence: "/"
        enabled: panelVisible && !quickInput.inputActive
            && !todoList.searchActive && !ideaList.searchActive && !logList.searchActive
        onActivated: {
            if (tabBar.currentIndex === 0) todoList.focusSearch();
            else if (tabBar.currentIndex === 1) ideaList.focusSearch();
            else logList.focusSearch();
        }
    }
    // ── 操作快捷 ──
    // Ctrl+R 刷新（与 :r 命令一致，附带 toast 反馈）
    Shortcut {
        sequence: "Ctrl+R"
        enabled: panelVisible
        onActivated: {
            dataFetcher.reload();
            panel.showToast("🔄 刷新中...");
        }
    }
    Shortcut {
        sequence: "Ctrl+,"
        enabled: panelVisible
        onActivated: settingsPanel.visible ? settingsPanel.close() : settingsPanel.open()
    }
    // Ctrl+Q 关闭最顶层弹窗或面板（Ctrl+G 在 Qt6.11/Wayland 下被吞为 BEL，用 Ctrl+Q 替代）
    Shortcut {
        sequence: "Ctrl+Q"
        enabled: panelVisible
        onActivated: panel.closeTopOrSelf()
    }

    // ── 删除项 Process（vim dd 触发） ──
    Process {
        id: deleteProc
        running: false
        property string pendingType: ""
        property var onSuccess: null
        stdout: StdioCollector {}
        stderr: StdioCollector { id: deleteStderr }
        onExited: function(exitCode, exitStatus) {
            var t = pendingType;
            var cb = onSuccess;
            pendingType = "";
            onSuccess = null;

            if (exitCode !== 0) {
                var detail = deleteStderr.text.trim();
                showToast("❌ 删除失败" + (detail ? "：" + detail.split("\n")[0] : "（退出码 " + exitCode + "）"));
                return;
            }

            showToast("🗑️  已删除");
            if (typeof cb === "function") cb();
            if (t) reloadData(t);
        }
    }

    // ── Toast 反馈层 ──
    Popup {
        id: toast
        parent: panel.contentItem
        x: (panel.contentItem.width - width) / 2
        y: panel.contentItem.height - height - 24
        width: Math.min(toastLabel.implicitWidth + 32, panel.contentItem.width - 32)
        height: toastLabel.implicitHeight + 20
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        padding: 10
        background: Rectangle {
            radius: 8
            color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.92)
            border.color: Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.4)
            border.width: 1
        }
        contentItem: Text {
            id: toastLabel
            color: theme.text
            font.pixelSize: cfg.fontSmall
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
        function show() {
            toastTimer.restart();
            open();
        }
        Timer {
            id: toastTimer
            interval: 2500
            repeat: false
            onTriggered: toast.close()
        }
    }
}
