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

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: true

    implicitWidth: Math.min(parent ? parent.width * 0.92 : 380, 420)
    implicitHeight: Math.min(contentColumn.implicitHeight + padding * 2, parent ? parent.height * 0.8 : 460)
    padding: 16

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // Quickshell 下 Popup 不自动抢焦点，打开时交给内容，Esc/Ctrl+Enter 才能生效
    onOpened: contentItem.forceActiveFocus()
    // 关闭后把焦点还给所属列表，保证 j/k/e 等继续可用
    onClosed: {
        if (parent && parent.focusList) parent.focusList();
    }

    background: Rectangle {
        radius: 12
        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
    }

    function openEdit(t, id) {
        root.type = t;
        root.itemId = id;
        root.formData = ({});
        root.priorityValue = "P2";
        root.loadError = "";
        root.loading = true;
        loadProc.command = ["starcatch", "--json", t, "show", id];
        loadProc.running = true;
        root.open();
    }

    // 回填表单（按类型把 show 的 JSON 映射到各字段）
    function fillForm(raw) {
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
        }
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
                var detail = loadStderr.text.trim();
                root.loadError = "加载失败" + (detail ? "：" + detail.split("\n")[0] : "（退出码 " + exitCode + "）");
                return;
            }

            var txt = loadStdout.text.trim();
            if (!txt) {
                root.loadError = "加载失败：未取到数据";
                return;
            }

            try {
                root.fillForm(JSON.parse(txt));
                root.loadError = "";
            } catch (e) {
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
                root.close();
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
                onClicked: root.close()
                contentItem: Text {
                    text: "✕"
                    color: theme.overlay0
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

        // ── 加载中 ──
        BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: root.loading
            palette { mid: theme ? theme.blue : "#89b4fa" }
        }

        // ── 加载错误 ──
        Text {
            Layout.fillWidth: true
            visible: root.loadError !== ""
            text: root.loadError
            color: theme.red
            font.pixelSize: cfg.fontSmall
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        // ── Todo 表单 ──
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.type === "todo" && !root.loading && root.loadError === ""

            Text { text: "标题"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: titleField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "必填"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "描述"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextArea {
                id: descField
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                wrapMode: Text.Wrap
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
                Keys.onPressed: function(event) {
                    if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        root.save(); event.accepted = true;
                    }
                }
            }

            Text { text: "优先级"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
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
                            color: parent.checked ? theme.blue : theme.overlay0
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

            Text { text: "截止日期"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: dueField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "YYYY-MM-DD 或 明天/next Monday · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "标签"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: tagsField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "逗号分隔 · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "项目"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: projectField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
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

            Text { text: "标题"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: ideaTitleField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "必填"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "内容"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextArea {
                id: contentField
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                wrapMode: Text.Wrap
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
                Keys.onPressed: function(event) {
                    if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        root.save(); event.accepted = true;
                    }
                }
            }

            Text { text: "来源"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: sourceField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "标签"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: ideaTagsField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "逗号分隔 · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "项目"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: ideaProjectField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
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

            Text { text: "内容"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextArea {
                id: logContentField
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "必填"
                font.pixelSize: cfg.fontBase
                wrapMode: Text.Wrap
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
                Keys.onPressed: function(event) {
                    if ((event.modifiers & Qt.ControlModifier) && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
                        root.save(); event.accepted = true;
                    }
                }
            }

            Text { text: "心情"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: moodField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "如 happy / sad · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "标签"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: logTagsField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "逗号分隔 · 留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
                }
            }

            Text { text: "项目"; color: theme.overlay0; font.pixelSize: cfg.fontTiny; Layout.fillWidth: true }
            TextField {
                id: logProjectField
                onAccepted: root.save()
                Layout.fillWidth: true
                color: theme.text
                placeholderTextColor: theme.overlay0
                placeholderText: "留空清除"
                font.pixelSize: cfg.fontBase
                verticalAlignment: Text.AlignVCenter
                background: Rectangle {
                    radius: 6
                    color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                    border.width: parent.activeFocus ? 1 : 0
                    border.color: Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.5)
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
                    color: theme.overlay0
                    font.pixelSize: cfg.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                        : "transparent"
                }
                onClicked: root.close()
            }
        }
    }
}
