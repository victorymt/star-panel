import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "EditorKeys.js" as EditorKeys
import "StarcatchCommands.js" as StarcatchCommands

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
    property int activeTabIndex: cfg.defaultTab

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
    function showToast(msg, kind) {
        toastLabel.text = msg;
        toast.kind = kind || toast.kindForMessage(msg);
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
        else if (todoList.editPopupControl.visible)   todoList.editPopupControl.handleEscape();
        else if (ideaList.editPopupControl.visible)   ideaList.editPopupControl.handleEscape();
        else if (logList.editPopupControl.visible)    logList.editPopupControl.handleEscape();
        else if (todoList.detailPopupControl.visible) todoList.detailPopupControl.close();
        else if (ideaList.detailPopupControl.visible) ideaList.detailPopupControl.close();
        else if (logList.detailPopupControl.visible)  logList.detailPopupControl.close();
        else                                   panelVisible = false;
    }

    // ── 切换 tab（vim h/l 用） ──
    function switchTab(delta) {
        var len = tabBar.tabs.length;
        setMainTab((tabBar.currentIndex + delta + len) % len);
        focusCurrentList();
    }

    // 仅切换主面板 tab，不抢焦点（供快速输入 Tab 切类型时联动）
    function setMainTab(index) {
        var next = Number(index);
        if (!isFinite(next) || next < 0 || next >= tabBar.tabs.length) return;
        next = Math.floor(next);
        if (panel.activeTabIndex !== next)
            panel.activeTabIndex = next;
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

    function resetCommandDeleteConfirmation() {
        commandDeleteArmed = false;
        commandDeleteType = "";
        commandDeleteId = "";
        commandDeleteReset.stop();
    }

    function deleteCurrentItem() {
        var list = currentList();
        var item = list.currentItem();
        var type = list.itemType;
        var id = item && item.id ? String(item.id) : "";

        if (!id) {
            resetCommandDeleteConfirmation();
            list.deleteCurrentItem();
            return;
        }

        // A second command only confirms the same item that was armed first.
        if (!commandDeleteArmed || commandDeleteType !== type || commandDeleteId !== id) {
            commandDeleteArmed = true;
            commandDeleteType = type;
            commandDeleteId = id;
            commandDeleteReset.restart();
            showToast("再次输入 :delete 确认删除");
            return;
        }

        resetCommandDeleteConfirmation();
        deleteItem(type, id);
        showToast("🗑️ 删除中...");
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
        var edit = EditorKeys.apply(field.text, field.cursorPosition, event.key);
        if (!edit.handled) return false;
        field.text = edit.text;
        field.cursorPosition = edit.cursor;
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
        deleteProc.command = StarcatchCommands.deleteCommand(cfg.starcatchPath, type, id);
        deleteProc.timedOut = false;
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
        return clr ? clr.overlay0 : "#a6adc8";
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
    property bool commandDeleteArmed: false
    property string commandDeleteType: ""
    property string commandDeleteId: ""
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
            // 显示时立即刷新一次，避免长时间隐藏后看到过期数据
            dataFetcher.reload();
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

        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.97)
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

                BusyIndicator {
                    visible: dataFetcher.loading
                    running: visible
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                    palette { mid: theme.blue }
                }

                Button {
                    flat: true
                    Layout.preferredWidth: cfg.iconButtonSize
                    Layout.preferredHeight: cfg.iconButtonSize
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
                    ToolTip.text: dataFetcher.loading ? "正在刷新" : "刷新"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                }

                Button {
                    flat: true
                    Layout.preferredWidth: cfg.iconButtonSize
                    Layout.preferredHeight: cfg.iconButtonSize
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
                    ToolTip.text: "设置"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                }

                Button {
                    flat: true
                    Layout.preferredWidth: cfg.iconButtonSize
                    Layout.preferredHeight: cfg.iconButtonSize
                    onClicked: helpPanel.open()
                    contentItem: Text {
                        text: "?"
                        color: theme.subtext1
                        font.pixelSize: cfg.fontLarge
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.6)
                            : "transparent"
                    }
                    ToolTip.text: "快捷键帮助"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                }

                Button {
                    flat: true
                    Layout.preferredWidth: cfg.iconButtonSize
                    Layout.preferredHeight: cfg.iconButtonSize
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
                    ToolTip.text: "关闭"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                }
            }

            // ── 选项卡 ──
            RowLayout {
                id: tabBar
                Layout.fillWidth: true
                spacing: 4
                readonly property int currentIndex: panel.activeTabIndex

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
                        onClicked: panel.setMainTab(index)

                        contentItem: Text {
                            text: modelData.label
                            color: tabBar.currentIndex === index ? theme.text : theme.subtext1
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

            // ── 数据刷新协调器 ──
            ReloadCoordinator {
                id: dataFetcher
                starcatchPath: cfg.starcatchPath
                logFilterDays: cfg.normalizeLogFilterDays(cfg.logFilterDays)
                activeTabIndex: tabBar.currentIndex
                panelVisible: panel.panelVisible
            }

            // ── 错误提示 ──
            Rectangle {
                Layout.fillWidth: true
                visible: dataFetcher.activeError !== ""
                Layout.preferredHeight: visible ? errorRow.implicitHeight + 12 : 0
                radius: 6
                color: Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.12)

                RowLayout {
                    id: errorRow
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Text {
                        id: errorText
                        text: dataFetcher.activeError
                        color: theme.red
                        font.pixelSize: cfg.fontSmall
                        wrapMode: Text.WordWrap
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                    }

                    Button {
                        flat: true
                        onClicked: dataFetcher.reload(dataFetcher.activeReloadType)
                        contentItem: Text {
                            text: "重试"
                            color: theme.text
                            font.pixelSize: cfg.fontSmall
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: parent.hovered || parent.visualFocus
                                ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.18)
                                : "transparent"
                        }
                    }
                }
            }

            // ── 内容区域 ──
            StackLayout {
                id: tabContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex

                TodoList { id: todoList; items: dataFetcher.todos; loading: dataFetcher.todoLoading }
                IdeaList { id: ideaList; items: dataFetcher.ideas; loading: dataFetcher.ideaLoading }
                LogList  { id: logList;  items: dataFetcher.logs;  loading: dataFetcher.logLoading }
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

    Shortcut { sequence: "Ctrl+1"; enabled: panelVisible; onActivated: panel.setMainTab(0) }
    Shortcut { sequence: "Ctrl+2"; enabled: panelVisible; onActivated: panel.setMainTab(1) }
    Shortcut { sequence: "Ctrl+3"; enabled: panelVisible; onActivated: panel.setMainTab(2) }

    Shortcut {
        sequence: "Ctrl+Tab"
        enabled: panelVisible
        onActivated: panel.setMainTab((tabBar.currentIndex + 1) % tabBar.tabs.length)
    }
    Shortcut {
        sequence: "Ctrl+Shift+Tab"
        enabled: panelVisible
        onActivated: panel.setMainTab((tabBar.currentIndex - 1 + tabBar.tabs.length) % tabBar.tabs.length)
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
    Timer {
        id: commandDeleteReset
        interval: 2500
        repeat: false
        onTriggered: panel.resetCommandDeleteConfirmation()
    }

    Process {
        id: deleteProc
        running: false
        property string pendingType: ""
        property var onSuccess: null
        property bool timedOut: false
        stdout: StdioCollector {}
        stderr: StdioCollector { id: deleteStderr }
        onExited: function(exitCode, exitStatus) {
            var timedOut = deleteProc.timedOut;
            deleteProc.timedOut = false;
            var t = pendingType;
            var cb = onSuccess;
            pendingType = "";
            onSuccess = null;

            if (timedOut) {
                return;
            }

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

    ProcessGuard {
        process: deleteProc
        onTimeout: {
            deleteProc.timedOut = true;
            showToast("❌ 删除超时，请检查 Starcatch 是否运行");
        }
    }

    // ── Toast 反馈层 ──
    Popup {
        id: toast
        parent: backdrop
        x: (backdrop.width - width) / 2
        y: Math.max(12, backdrop.height - height - quickInput.height - 32)
        width: Math.min(toastLabel.implicitWidth + 32, backdrop.width - 24)
        height: toastLabel.implicitHeight + 20
        modal: false
        focus: false
        closePolicy: Popup.NoAutoClose
        padding: 10

        property string kind: "info"
        readonly property color accentColor: kind === "error" ? theme.red
            : kind === "warning" ? theme.peach
            : kind === "success" ? theme.green
            : theme.blue

        function kindForMessage(message) {
            var value = (message || "").toString();
            if (value.indexOf("❌") === 0) return "error";
            if (value.indexOf("⚠") === 0 || value.indexOf("再次") === 0 || value.indexOf("再按") === 0)
                return "warning";
            if (value.indexOf("✅") === 0 || value.indexOf("✨") === 0
                    || value.indexOf("📋 已复制") === 0 || value.indexOf("🗑️  已删除") === 0)
                return "success";
            return "info";
        }

        background: Rectangle {
            radius: 8
            color: Qt.rgba(toast.accentColor.r, toast.accentColor.g, toast.accentColor.b, 0.16)
            border.color: Qt.rgba(toast.accentColor.r, toast.accentColor.g, toast.accentColor.b, 0.7)
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
