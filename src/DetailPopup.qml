import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Popup {
    id: root

    property string type: "todo"
    property var itemData: ({})
    property string pendingReload: ""  // type to reload after action succeeds

    function imageSource(path) {
        if (!path) return "";
        if (path.indexOf("file://") === 0) return path;
        return "file://" + path;
    }

    function imageName(path) {
        if (!path) return "";
        var parts = path.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : path;
    }

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: true

    implicitWidth: Math.min(parent ? parent.width * 0.9 : 380, 380)
    implicitHeight: Math.min(contentColumn.implicitHeight + padding * 2, parent ? parent.height * 0.7 : 400)
    padding: 16

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // Quickshell 下 Popup 不会自动抢焦点，CloseOnEscape 失灵；
    // 打开时把焦点交给内容，Esc 才能由 contentItem 的 Keys 处理。
    onOpened: contentItem.forceActiveFocus()
    // 关闭后把焦点还给所属列表，保证 gt/j/k 等继续可用。
    onClosed: {
        if (parent && parent.focusList) parent.focusList();
    }

    background: Rectangle {
        radius: 12
        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
    }

    contentItem: ColumnLayout {
        id: contentColumn
        spacing: 10

        // Escape 关闭弹窗（contentItem 拿到焦点后才生效，见 root.onOpened）
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.close();
                event.accepted = true;
            }
        }

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: type === "todo" ? "📋 待办详情"
                    : type === "idea" ? "💭 灵感详情"
                    : "📓 日志详情"
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

        // ── Todo Fields ──
        ColumnLayout {
            spacing: 6
            visible: type === "todo"
            Layout.fillWidth: true

            Text {
                text: itemData.title || ""
                color: theme.text
                font.pixelSize: cfg.fontBase
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                text: itemData.description || ""
                color: theme.subtext0
                font.pixelSize: cfg.fontBase
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                visible: itemData.description !== undefined && itemData.description !== null && itemData.description !== ""
            }

            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 4
                Layout.fillWidth: true

                Text { text: "优先级"; color: theme.overlay0; font.pixelSize: cfg.fontSmall }
                Text {
                    text: {
                        var p = itemData.priority;
                        if (p === "🔴") return "🔴 高";
                        if (p === "🟡") return "🟡 中";
                        if (p === "🟢") return "🟢 低";
                        return "⚪ 无";
                    }
                    color: theme.text; font.pixelSize: cfg.fontSmall
                }

                Text { text: "状态"; color: theme.overlay0; font.pixelSize: cfg.fontSmall }
                Text {
                    text: itemData.status === "⬜" ? "⬜ 待办"
                        : itemData.status === "✅" ? "✅ 已完成"
                        : "📦 已归档"
                    color: theme.text; font.pixelSize: cfg.fontSmall
                }

                Text {
                    text: "截止日期"
                    color: theme.overlay0
                    font.pixelSize: cfg.fontSmall
                    visible: itemData.due !== undefined && itemData.due !== null && itemData.due !== "-"
                }
                Text {
                    text: panel.getDueDisplay(itemData.due)
                    color: theme.text
                    font.pixelSize: cfg.fontSmall
                    visible: itemData.due !== undefined && itemData.due !== null && itemData.due !== "-"
                }
            }
        }

        // ── Idea Fields ──
        ColumnLayout {
            spacing: 6
            visible: type === "idea"
            Layout.fillWidth: true

            Text {
                text: itemData.title || "(untitled)"
                color: theme.text
                font.pixelSize: cfg.fontBase
                font.bold: true
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                text: itemData.content || ""
                color: theme.subtext0
                font.pixelSize: cfg.fontBase
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 12
                Text {
                    text: "📎 " + (itemData.source || "?")
                    color: theme.overlay0
                    font.pixelSize: cfg.fontSmall
                }
                Text {
                    text: "🕐 " + (itemData.time || "")
                    color: theme.overlay0
                    font.pixelSize: cfg.fontSmall
                }
            }
        }

        // ── Log Fields ──
        ColumnLayout {
            spacing: 6
            visible: type === "log"
            Layout.fillWidth: true

            Text {
                text: itemData.content || ""
                color: theme.text
                font.pixelSize: cfg.fontBase
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Text {
                text: itemData.title || ""
                color: theme.overlay0
                font.pixelSize: cfg.fontSmall
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: 6
                Layout.fillWidth: true
                visible: itemData.images !== undefined && itemData.images !== null && itemData.images.length > 0

                Text {
                    text: "图片 · " + ((itemData.images || []).length)
                    color: theme.overlay0
                    font.pixelSize: cfg.fontTiny
                    Layout.fillWidth: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: itemData.images || []

                        delegate: Rectangle {
                            width: 84
                            height: 106
                            radius: 8
                            color: Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                            border.width: 1
                            border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)

                            Image {
                                id: thumb
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 6
                                height: 72
                                source: root.imageSource(modelData)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                clip: true
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                text: root.imageName(modelData)
                                color: theme.overlay0
                                font.pixelSize: cfg.fontTiny
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                }
            }
        }

        // ── Tags ──
        TagList {
            tags: itemData.tags || []
            tagColor: theme ? theme.sapphire : "#74c7ec"
            visible: itemData.tags !== undefined && itemData.tags !== null && itemData.tags.length > 0
        }

        // ── Todo Action Buttons ──
        RowLayout {
            spacing: 8
            visible: type === "todo"
            Layout.fillWidth: true

            Button {
                id: actionBtn
                Layout.fillWidth: true
                flat: true
                property var actions: {
                    if (itemData.rawStatus === "Pending")  return { cmd: "done",   label: "✓ 标记完成" };
                    if (itemData.rawStatus === "Done")     return { cmd: "reopen", label: "↩ 恢复待办" };
                    if (itemData.rawStatus === "Archived")  return { cmd: "reopen", label: "↩ 恢复待办" };
                    return { cmd: "", label: "" };
                }

                contentItem: Text {
                    text: actionBtn.actions.label
                    color: actionBtn.actions.cmd === "done" ? theme.green : theme.blue
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
                onClicked: {
                    if (!itemData.id || !actionBtn.actions.cmd) return;
                    root.runAction(actionBtn.actions.cmd, "todo");
                }
            }

            Button {
                id: archiveBtn
                Layout.fillWidth: true
                flat: true
                visible: itemData.rawStatus !== "Archived"

                contentItem: Text {
                    text: "📦 归档"
                    color: theme.peach
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
                onClicked: {
                    if (!itemData.id) return;
                    root.runAction("archive", "todo");
                }
            }

            Button {
                Layout.fillWidth: true
                flat: true

                contentItem: Text {
                    text: "关闭"
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

        // ── Idea/Log 操作按钮（编辑 + 删除 + 关闭） ──
        RowLayout {
            spacing: 8
            visible: type !== "todo"
            Layout.fillWidth: true

            Button {
                Layout.fillWidth: true
                flat: true
                contentItem: Text {
                    text: "✏️ 编辑"
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
                onClicked: {
                    if (!itemData.id) { panel.showToast("⚠️ 该项没有 id，无法编辑"); return; }
                    // 关闭详情 → 打开编辑（避免两个 popup 叠加）
                    root.close();
                    if (parent && parent.editPopup) parent.editPopup.openEdit(root.type, itemData.id);
                }
            }

            Button {
                Layout.fillWidth: true
                flat: true
                contentItem: Text {
                    text: "🗑️ 删除"
                    color: theme.peach
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
                onClicked: {
                    if (!itemData.id) { panel.showToast("⚠️ 该项没有 id，无法删除"); return; }
                    panel.deleteItem(root.type, itemData.id, function() {
                        root.close();
                    });
                    panel.showToast("🗑️ 删除中...");
                }
            }

            Button {
                Layout.fillWidth: true
                flat: true
                contentItem: Text {
                    text: "关闭"
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

    // ── 动作执行 Process ──
    // 用 Process 替代 execDetached，确保写入完成后才刷新列表，
    // 失败时通过 panel 的 toast 给用户反馈。
    Process {
        id: actionProc
        running: false
        stdout: StdioCollector {}
        stderr: StdioCollector {
            id: actionStderr
        }
        onExited: function(exitCode, exitStatus) {
            var t = root.pendingReload;
            root.pendingReload = "";
            if (exitCode !== 0) {
                var detail = actionStderr.text.trim();
                panel.showToast("❌ 操作失败" + (detail ? "：" + detail.split("\n")[0] : "（退出码 " + exitCode + "）"));
                return;
            }

            root.close();
            if (t) panel.reloadData(t);
        }
    }

    function runAction(cmd, reloadType) {
        if (!itemData.id) return;
        pendingReload = reloadType;
        actionProc.command = ["starcatch", "todo", cmd, itemData.id];
        actionProc.running = true;
    }
}
