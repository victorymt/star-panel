import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/// EditPopup — 条目编辑弹窗
/// 列表上按 e 触发：starcatch --json <type> show 回填表单，
/// 保存时全字段直传 starcatch <type> edit（空串=清空，后端三态语义）。
Popup {
    id: root

    property string type: "todo"
    property string itemId: ""
    property var formData: ({})
    property string priorityValue: "P2"   // todo 优先级单选状态
    property bool loading: false
    property string loadError: ""
    property string originalLogImagesText: ""
    property bool dirty: false
    property bool hydrating: false

    onPriorityValueChanged: markDirty()

    modal: true
    // 编辑态不允许点外部误关；Esc、取消和关闭按钮统一走 requestClose()。
    closePolicy: Popup.NoAutoClose
    dim: true

    implicitWidth: Math.min(parent ? parent.width * 0.94 : 420, 420)
    implicitHeight: Math.min(
        Math.max(360, editBodyColumn.implicitHeight + 150 + padding * 2),
        parent ? parent.height * 0.86 : 600
    )
    padding: 16

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // Quickshell 下 Popup 不自动抢焦点，打开时交给内容，Esc/Ctrl+Enter 才能生效
    onOpened: {
        contentItem.forceActiveFocus();
        Qt.callLater(function() { editScroll.contentItem.contentY = 0; });
    }
    // 关闭后把焦点还给所属列表，保证 j/k/e 等继续可用
    onClosed: {
        if (discardPopup.visible) discardPopup.close();
        if (!saveProc.running) clipboardImagePaste.cleanupAll();
        root.dirty = false;
        root.hydrating = false;
        if (parent && parent.focusList) parent.focusList();
    }

    background: Rectangle {
        radius: 12
        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
    }

    ClipboardImagePaste {
        id: clipboardImagePaste
        toastTarget: panel
        onImageCaptured: function(path) {
            logImagesText.text = clipboardImagePaste.appendPath(logImagesText.text, path);
        }
    }

    function openEdit(t, id) {
        clipboardImagePaste.cleanupAll();
        root.dirty = false;
        root.type = t;
        root.itemId = id;
        root.formData = ({});
        root.priorityValue = "P2";
        root.loadError = "";
        root.originalLogImagesText = "";
        root.startLoad();
        root.open();
    }

    function startLoad() {
        if (!root.itemId || loadProc.running) return;
        root.hydrating = true;
        root.loadError = "";
        root.loading = true;
        loadProc.command = ["starcatch", "--json", root.type, "show", root.itemId];
        loadProc.running = true;
    }

    function focusPrimaryField() {
        var field = root.type === "todo" ? titleField
            : root.type === "idea" ? ideaTitleField : logContentField;
        field.forceActiveFocus();
        field.cursorPosition = field.text.length;
    }

    function markDirty() {
        if (!root.hydrating && !root.loading && root.visible)
            root.dirty = true;
    }

    function requestClose() {
        if (saveProc.running) {
            panel.showToast("⏳ 正在保存...");
            return;
        }
        if (root.dirty) {
            discardPopup.open();
            return;
        }
        root.close();
    }

    function handleEscape() {
        if (discardPopup.visible) {
            discardPopup.close();
            return;
        }
        requestClose();
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

    function normalizeImageText(text) {
        return splitImagePaths(text).join("\n");
    }

    // 回填表单（按类型把 show 的 JSON 映射到各字段）
    function fillForm(raw) {
        root.hydrating = true;
        root.formData = raw;
        if (root.type === "todo") {
            titleField.text = raw.title || "";
            descField.text = raw.description || "";
            root.priorityValue = raw.priority || "P2";
            dueField.text = raw.due_date || "";
            tagsField.text = (raw.tags || []).join(", ");
            projectField.text = raw.project || "";
        } else if (root.type === "idea") {
            ideaTitleField.text = raw.title || "";
            contentField.text = raw.content || "";
            sourceField.text = raw.source || "";
            ideaTagsField.text = (raw.tags || []).join(", ");
            ideaProjectField.text = raw.project || "";
        } else {
            logContentField.text = raw.content || "";
            moodField.text = raw.mood || "";
            logTagsField.text = (raw.tags || []).join(", ");
            logProjectField.text = raw.project || "";
            logImagesText.text = (raw.images || []).join("\n");
            root.originalLogImagesText = logImagesText.text;
        }
        root.hydrating = false;
        root.dirty = false;
        Qt.callLater(function() { root.focusPrimaryField(); });
    }

    // 全字段直传：空串=清空（后端三态）。所有字段显式传，不做 diff。
    function save() {
        if (!root.itemId) return;
        var cmd;
        if (root.type === "todo") {
            var title = titleField.text.trim();
            if (!title) { panel.showToast("⚠️ 标题不能为空"); return; }
            cmd = ["starcatch", "todo", "edit", root.itemId,
                   "--title", title,
                   "--desc", descField.text,
                   "-p", root.priorityValue,
                   "--due", dueField.text.trim(),
                   "-t", tagsField.text.trim(),
                   "-P", projectField.text.trim()];
        } else if (root.type === "idea") {
            var ititle = ideaTitleField.text.trim();
            if (!ititle) { panel.showToast("⚠️ 标题不能为空"); return; }
            cmd = ["starcatch", "idea", "edit", root.itemId,
                   "--title", ititle,
                   "-c", contentField.text,
                   "-s", sourceField.text.trim(),
                   "-t", ideaTagsField.text.trim(),
                   "-P", ideaProjectField.text.trim()];
        } else {
            var content = logContentField.text.trim();
            if (!content) { panel.showToast("⚠️ 内容不能为空"); return; }
            cmd = ["starcatch", "log", "edit", root.itemId,
                   "-c", content,
                   "-m", moodField.text.trim(),
                   "-t", logTagsField.text.trim(),
                   "-P", logProjectField.text.trim()];
            var originalImages = root.normalizeImageText(root.originalLogImagesText);
            var currentImages = root.normalizeImageText(logImagesText.text);
            if (currentImages !== originalImages) {
                var imagePaths = root.splitImagePaths(logImagesText.text);
                if (imagePaths.length === 0) {
                    cmd.push("--clear-images");
                } else {
                    for (var i = 0; i < imagePaths.length; i++) {
                        cmd.push("--image", imagePaths[i]);
                    }
                }
            }
        }
        saveProc.pendingReload = root.type;
        saveProc.command = cmd;
        saveProc.running = true;
    }

    // ── 回填 Process ──
    Process {
        id: loadProc
        running: false
        stdout: StdioCollector { id: loadStdout }
        stderr: StdioCollector { id: loadStderr }
        onExited: function(exitCode, exitStatus) {
            root.loading = false;

            if (exitCode !== 0) {
                root.hydrating = false;
                var detail = loadStderr.text.trim();
                root.loadError = "加载失败" + (detail ? "：" + detail.split("\n")[0] : "（退出码 " + exitCode + "）");
                return;
            }

            var txt = loadStdout.text.trim();
            if (!txt) {
                root.hydrating = false;
                root.loadError = "加载失败：未取到数据";
                return;
            }

            try {
                root.fillForm(JSON.parse(txt));
                root.loadError = "";
            } catch (e) {
                root.hydrating = false;
                root.loadError = "解析失败：" + e.message;
            }
        }
    }

    // ── 保存 Process ──
    Process {
        id: saveProc
        running: false
        property string pendingReload: ""
        stdout: StdioCollector {}
        stderr: StdioCollector { id: saveStderr }
        onExited: function(exitCode, exitStatus) {
            var t = saveProc.pendingReload;
            saveProc.pendingReload = "";
            if (exitCode !== 0) {
                var detail = saveStderr.text.trim();
                panel.showToast("❌ 保存失败" + (detail ? "：" + detail.split("\n")[0] : "（退出码 " + exitCode + "）"));
                return;
            }

            panel.showToast("✅ 已更新");
            root.dirty = false;
            clipboardImagePaste.cleanupAll();
            root.close();
            if (t) panel.reloadData(t);
        }
    }

    contentItem: ColumnLayout {
        id: contentColumn
        spacing: 10

        // Escape 关闭；Ctrl+Enter 保存（单行 TextField 不消费则传播至此）
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (saveProc.running) {
                    panel.showToast("⏳ 正在保存...");
                    event.accepted = true;
                    return;
                }
                panel.switchToEnglishIme();
                root.handleEscape();
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                root.save();
                event.accepted = true;
            }
        }

        // ── Header ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: root.type === "todo" ? "✏️ 编辑待办"
                    : root.type === "idea" ? "✏️ 编辑灵感"
                    : "✏️ 编辑日志"
                color: theme.text
                font.pixelSize: cfg.fontLarge
                font.bold: true
            }

            Item { Layout.fillWidth: true }

            Button {
                flat: true
                enabled: !saveProc.running
                onClicked: root.requestClose()
                contentItem: Text {
                    text: "✕"
                    color: theme.subtext1
                    font.pixelSize: cfg.fontBase
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                        : "transparent"
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.3)
        }

        ScrollView {
            id: editScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 160
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                id: editBodyColumn
                width: editScroll.availableWidth
                spacing: 10

        // ── 加载中 ──
        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: root.loading
            palette { mid: theme ? theme.blue : "#89b4fa" }
        }

        // ── 加载错误 ──
        ColumnLayout {
            Layout.fillWidth: true
            visible: root.loadError !== ""
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: root.loadError
                color: theme.red
                font.pixelSize: cfg.fontSmall
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                Layout.alignment: Qt.AlignHCenter
                flat: true
                onClicked: root.startLoad()
                contentItem: Text {
                    text: "↻ 重试"
                    color: theme.blue
                    font.pixelSize: cfg.fontSmall
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                        : "transparent"
                }
            }
        }

        // ── Todo 表单 ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.type === "todo" && !root.loading && root.loadError === ""

            Text { text: "标题"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: titleField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "必填"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(titleField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "描述"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            ScrollView {
                id: todoDescriptionScroll
                Layout.fillWidth: true
                Layout.minimumHeight: 72
                Layout.preferredHeight: 120
                Layout.maximumHeight: 180
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: descField.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }

                TextArea {
                    id: descField
                    onTextChanged: root.markDirty()
                    width: todoDescriptionScroll.availableWidth
                    color: theme.text
                    placeholderTextColor: theme.subtext1
                    placeholderText: "留空清除"
                    font.pixelSize: cfg.fontBase
                    wrapMode: Text.Wrap
                    background: null
                    Keys.onPressed: function(event) {
                        if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                            root.save(); event.accepted = true;
                        } else {
                            panel.handleEmacsEdit(descField, event);
                        }
                    }
                }
            }

            Text { text: "优先级"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: [
                        { l: "🔴 P0", v: "P0" },
                        { l: "🟡 P1", v: "P1" },
                        { l: "🟢 P2", v: "P2" },
                        { l: "⚪ P3", v: "P3" }
                    ]
                    delegate: Button {
                        required property var modelData
                        flat: true
                        Layout.preferredWidth: implicitWidth
                        checked: root.priorityValue === modelData.v
                        onClicked: root.priorityValue = modelData.v
                        contentItem: Text {
                            text: modelData.l
                            color: parent.checked ? theme.blue : theme.subtext1
                            font.pixelSize: cfg.fontSmall
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: parent.checked
                                ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.2)
                                : (parent.hovered
                                    ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                                    : "transparent")
                        }
                    }
                }
                Item { Layout.fillWidth: true }
            }

            Text { text: "截止日期"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: dueField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "YYYY-MM-DD 或 明天/next Monday · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(dueField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "标签"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: tagsField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "逗号分隔 · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(tagsField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "项目"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: projectField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(projectField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }
        }

        // ── Idea 表单 ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.type === "idea" && !root.loading && root.loadError === ""

            Text { text: "标题"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: ideaTitleField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "必填"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(ideaTitleField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "内容"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            ScrollView {
                id: ideaContentScroll
                Layout.fillWidth: true
                Layout.minimumHeight: 96
                Layout.preferredHeight: 180
                Layout.maximumHeight: 240
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: contentField.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }

                TextArea {
                    id: contentField
                    onTextChanged: root.markDirty()
                    width: ideaContentScroll.availableWidth
                    color: theme.text
                    placeholderTextColor: theme.subtext1
                    placeholderText: "留空清除"
                    font.pixelSize: cfg.fontBase
                    wrapMode: Text.Wrap
                    background: null
                    Keys.onPressed: function(event) {
                        if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                            root.save(); event.accepted = true;
                        } else {
                            panel.handleEmacsEdit(contentField, event);
                        }
                    }
                }
            }

            Text { text: "来源"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: sourceField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(sourceField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "标签"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: ideaTagsField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "逗号分隔 · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(ideaTagsField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "项目"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: ideaProjectField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(ideaProjectField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }
        }

        // ── Log 表单 ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.type === "log" && !root.loading && root.loadError === ""

            Text { text: "内容"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            ScrollView {
                id: logContentScroll
                Layout.fillWidth: true
                Layout.minimumHeight: 96
                Layout.preferredHeight: 180
                Layout.maximumHeight: 240
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: logContentField.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }

                TextArea {
                    id: logContentField
                    onTextChanged: root.markDirty()
                    width: logContentScroll.availableWidth
                    color: theme.text
                    placeholderTextColor: theme.subtext1
                    placeholderText: "必填"
                    font.pixelSize: cfg.fontBase
                    wrapMode: Text.Wrap
                    background: null
                    Keys.onPressed: function(event) {
                        if (clipboardImagePaste.isPasteShortcut(event)) {
                            clipboardImagePaste.requestPaste(logContentField, true);
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                            root.save(); event.accepted = true;
                        } else {
                            panel.handleEmacsEdit(logContentField, event);
                        }
                    }
                }
            }

            Text { text: "心情"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: moodField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "如 happy / sad · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(moodField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "标签"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: logTagsField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "逗号分隔 · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(logTagsField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "项目"; color: theme.subtext1; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: logProjectField
                onTextChanged: root.markDirty()
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.subtext1
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                Keys.onPressed: function(event) { panel.handleEmacsEdit(logProjectField, event); }
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text {
                text: "图片路径"
                color: theme.subtext1
                font.pixelSize: cfg.fontTiny
                Layout.fillWidth: true
            }
            ScrollView {
                id: logImagesScroll
                Layout.fillWidth: true
                Layout.minimumHeight: 44
                Layout.preferredHeight: Math.min(96, Math.max(44, logImagesText.implicitHeight))
                Layout.maximumHeight: 96
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: logImagesText.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }

                TextArea {
                    id: logImagesText
                    onTextChanged: root.markDirty()
                    width: logImagesScroll.availableWidth
                    color: theme.text
                    placeholderTextColor: theme.subtext1
                    placeholderText: "路径或 Ctrl+V 粘贴图片 · 留空清除"
                    font.pixelSize: cfg.fontTiny
                    wrapMode: Text.WrapAnywhere
                    background: null
                    Keys.onPressed: function(event) {
                        if (clipboardImagePaste.isPasteShortcut(event)) {
                            clipboardImagePaste.requestPaste(logImagesText, true);
                            event.accepted = true;
                        } else if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                            root.save(); event.accepted = true;
                        } else {
                            panel.handleEmacsEdit(logImagesText, event);
                        }
                    }
                }
            }
        }
            }
        }

        // ── 操作按钮 ──
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: !root.loading && root.loadError === ""

            Button {
                Layout.fillWidth: true
                flat: true
                enabled: !saveProc.running
                contentItem: Text {
                    text: saveProc.running ? "保存中…" : "💾 保存 (Ctrl+Enter)"
                    color: theme.green
                    font.pixelSize: cfg.fontSmall
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                        : "transparent"
                }
                onClicked: root.save()
            }

            Button {
                Layout.fillWidth: true
                flat: true
                enabled: !saveProc.running
                contentItem: Text {
                    text: "取消"
                    color: theme.subtext1
                    font.pixelSize: cfg.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                        : "transparent"
                }
                onClicked: root.requestClose()
            }
        }
    }

    // ── 未保存改动确认 ──
    Popup {
        id: discardPopup
        parent: root.contentItem
        x: Math.max(8, (root.width - width) / 2)
        y: Math.max(8, (root.height - height) / 2)
        width: Math.max(240, Math.min(root.width - 16, 320))
        implicitHeight: discardColumn.implicitHeight + 24
        padding: 12
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose

        onOpened: contentItem.forceActiveFocus()

        background: Rectangle {
            radius: 8
            color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.99)
            border.width: 1
            border.color: Qt.rgba(theme.peach.r, theme.peach.g, theme.peach.b, 0.55)
        }

        contentItem: ColumnLayout {
            id: discardColumn
            focus: true
            spacing: 10

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    discardPopup.close();
                    event.accepted = true;
                }
            }

            Text {
                text: "放弃未保存的改动？"
                color: theme.text
                font.pixelSize: cfg.fontBase
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: "当前编辑内容还没有保存。"
                color: theme.subtext1
                font.pixelSize: cfg.fontSmall
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Button {
                    Layout.fillWidth: true
                    flat: true
                    onClicked: discardPopup.close()
                    contentItem: Text {
                        text: "继续编辑"
                        color: theme.blue
                        font.pixelSize: cfg.fontSmall
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.5)
                            : "transparent"
                    }
                }

                Button {
                    Layout.fillWidth: true
                    flat: true
                    onClicked: {
                        discardPopup.close();
                        root.dirty = false;
                        root.close();
                    }
                    contentItem: Text {
                        text: "放弃改动"
                        color: theme.red
                        font.pixelSize: cfg.fontSmall
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                    }
                    background: Rectangle {
                        radius: 6
                        color: parent.hovered
                            ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.16)
                            : "transparent"
                    }
                }
            }
        }
    }
}
