import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "StarcatchCommands.js" as StarcatchCommands

Popup {
    id: root

    property string type: "todo"
    property var itemData: ({})
    property string pendingReload: ""  // type to reload after action succeeds
    property int previewImageIndex: -1
    property var previewImages: []
    property bool previewOnly: false
    property bool deleteArmed: false

    signal editRequested(string itemType, var itemId)

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

    function openImagePreview(index) {
        var images = itemData.images || [];
        if (index < 0 || index >= images.length) return;
        previewImages = images;
        previewImageIndex = index;
        imagePreview.open();
    }

    function openImage(item, index) {
        root.type = "log";
        root.itemData = item || ({});
        var images = root.itemData.images || [];
        if (index < 0 || index >= images.length) return;
        root.previewImages = images;
        root.previewImageIndex = index;
        root.previewOnly = true;
        root.open();
    }

    function currentPreviewPath() {
        if (previewImageIndex < 0 || previewImageIndex >= previewImages.length) return "";
        return previewImages[previewImageIndex];
    }

    function currentPreviewSource() {
        return imageSource(currentPreviewPath());
    }

    function currentPreviewName() {
        return imageName(currentPreviewPath());
    }

    function nextPreviewImage() {
        if (previewImages.length <= 1) return;
        previewImageIndex = (previewImageIndex + 1) % previewImages.length;
    }

    function prevPreviewImage() {
        if (previewImages.length <= 1) return;
        previewImageIndex = (previewImageIndex - 1 + previewImages.length) % previewImages.length;
    }

    function copyItemText() {
        panel.copyItem(root.type, root.itemData);
    }

    function requestEdit() {
        if (!itemData.id) {
            panel.showToast("⚠️ 该项没有 id，无法编辑");
            return;
        }
        root.close();
        root.editRequested(root.type, itemData.id);
    }

    function requestDelete() {
        if (actionProc.running) {
            panel.showToast("⏳ 操作进行中...");
            return;
        }
        if (!itemData.id) {
            panel.showToast("⚠️ 该项没有 id，无法删除");
            return;
        }
        if (!root.deleteArmed) {
            root.deleteArmed = true;
            deleteReset.restart();
            panel.showToast("再次点击删除以确认");
            return;
        }
        root.deleteArmed = false;
        deleteReset.stop();
        panel.deleteItem(root.type, itemData.id, function() {
            root.close();
        });
        panel.showToast("🗑️ 删除中...");
    }

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: true

    implicitWidth: Math.min(parent ? parent.width * 0.94 : 560, 560)
    implicitHeight: Math.min(
        Math.max(300, bodyColumn.implicitHeight + 150 + padding * 2),
        parent ? parent.height * 0.78 : 520
    )
    padding: 16

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    // Quickshell 下 Popup 不会自动抢焦点，CloseOnEscape 失灵；
    // 打开时把焦点交给内容，Esc 才能由 contentItem 的 Keys 处理。
    onOpened: {
        root.deleteArmed = false;
        if (root.previewOnly) imagePreview.open();
        else {
            contentItem.forceActiveFocus();
            Qt.callLater(function() { detailScroll.contentItem.contentY = 0; });
        }
    }
    // 关闭后把焦点还给所属列表，保证 gt/j/k 等继续可用。
    onClosed: {
        root.deleteArmed = false;
        deleteReset.stop();
        if (parent && parent.focusList) parent.focusList();
    }

    Timer {
        id: deleteReset
        interval: 2500
        repeat: false
        onTriggered: root.deleteArmed = false
    }

    background: Rectangle {
        visible: !root.previewOnly
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
                if (imagePreview.visible) imagePreview.close();
                else root.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Y && !event.modifiers) {
                // y — 复制正文到剪切板（vim yank）
                root.copyItemText();
                event.accepted = true;
            } else if (event.key === Qt.Key_E && !event.modifiers) {
                root.requestEdit();
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
            id: detailScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 120
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                id: bodyColumn
                width: detailScroll.availableWidth
                spacing: 10

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

            MarkdownText {
                markdown: itemData.description || ""
                color: theme.subtext0
                font.pixelSize: cfg.fontBase
                Layout.fillWidth: true
                visible: itemData.description !== undefined && itemData.description !== null && itemData.description !== ""
            }

            GridLayout {
                columns: 2
                columnSpacing: 8
                rowSpacing: 4
                Layout.fillWidth: true

                Text { text: "优先级"; color: theme.subtext1; font.pixelSize: cfg.fontSmall }
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

                Text { text: "状态"; color: theme.subtext1; font.pixelSize: cfg.fontSmall }
                Text {
                    text: itemData.status === "⬜" ? "⬜ 待办"
                        : itemData.status === "✅" ? "✅ 已完成"
                        : "📦 已归档"
                    color: theme.text; font.pixelSize: cfg.fontSmall
                }

                Text {
                    text: "截止日期"
                    color: theme.subtext1
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

            MarkdownText {
                markdown: itemData.content || ""
                color: theme.subtext0
                font.pixelSize: cfg.fontBase
                Layout.fillWidth: true
            }

            RowLayout {
                spacing: 12
                Text {
                    text: "📎 " + (itemData.source || "?")
                    color: theme.subtext1
                    font.pixelSize: cfg.fontSmall
                }
                Text {
                    text: "🕐 " + (itemData.time || "")
                    color: theme.subtext1
                    font.pixelSize: cfg.fontSmall
                }
            }
        }

        // ── Log Fields ──
        ColumnLayout {
            spacing: 6
            visible: type === "log"
            Layout.fillWidth: true

            MarkdownText {
                markdown: itemData.content || ""
                color: theme.text
                font.pixelSize: cfg.fontBase
                Layout.fillWidth: true
            }

            Text {
                text: itemData.title || ""
                color: theme.subtext1
                font.pixelSize: cfg.fontSmall
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: 6
                Layout.fillWidth: true
                visible: itemData.images !== undefined && itemData.images !== null && itemData.images.length > 0

                Text {
                    text: "图片 · " + ((itemData.images || []).length)
                    color: theme.subtext1
                    font.pixelSize: cfg.fontTiny
                    Layout.fillWidth: true
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: itemData.images || []

                        delegate: Rectangle {
                            property int imageIndex: index
                            width: 84
                            height: 106
                            radius: 8
                            color: thumbMouse.containsMouse
                                ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.55)
                                : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.5)
                            border.width: 1
                            border.color: thumbMouse.containsMouse
                                ? Qt.rgba(theme.blue.r, theme.blue.g, theme.blue.b, 0.55)
                                : Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)

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
                                color: theme.subtext1
                                font.pixelSize: cfg.fontTiny
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                            }

                            MouseArea {
                                id: thumbMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.openImagePreview(parent.imageIndex)
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
            }
        }

        // ── Todo Action Buttons ──
        RowLayout {
            spacing: 8
            visible: type === "todo"
            Layout.fillWidth: true

            Button {
                id: actionBtn
                Layout.fillWidth: true
                Layout.preferredHeight: cfg.controlHeight
                flat: true
                enabled: !actionProc.running
                property var actions: {
                    if (itemData.rawStatus === "Pending")  return { cmd: "done",   label: "✓ 标记完成" };
                    if (itemData.rawStatus === "Done")     return { cmd: "reopen", label: "↩ 恢复待办" };
                    if (itemData.rawStatus === "Archived")  return { cmd: "reopen", label: "↩ 恢复待办" };
                    return { cmd: "", label: "" };
                }
                property color actionColor: actions.cmd === "done" ? theme.green : theme.blue

                contentItem: Text {
                    text: actionProc.running ? "处理中..." : actionBtn.actions.label
                    color: theme.crust
                    font.pixelSize: cfg.fontSmall
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(parent.actionColor.r, parent.actionColor.g, parent.actionColor.b, 0.95)
                        : Qt.rgba(parent.actionColor.r, parent.actionColor.g, parent.actionColor.b, 0.8)
                }
                onClicked: {
                    if (!itemData.id || !actionBtn.actions.cmd) return;
                    root.runAction(actionBtn.actions.cmd, "todo");
                }
            }

            Button {
                id: archiveBtn
                Layout.fillWidth: true
                Layout.preferredHeight: cfg.controlHeight
                flat: true
                visible: itemData.rawStatus !== "Archived"
                enabled: !actionProc.running

                contentItem: Text {
                    text: "📦 归档"
                    color: theme.peach
                    font.pixelSize: cfg.fontSmall
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.peach.r, theme.peach.g, theme.peach.b, 0.2)
                        : Qt.rgba(theme.peach.r, theme.peach.g, theme.peach.b, 0.1)
                    border.width: 1
                    border.color: Qt.rgba(theme.peach.r, theme.peach.g, theme.peach.b, 0.45)
                }
                onClicked: {
                    if (!itemData.id) return;
                    root.runAction("archive", "todo");
                }
            }

        }

        // ── 全类型通用操作──
        RowLayout {
            spacing: 8
            Layout.fillWidth: true

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: cfg.compactControlHeight
                flat: true
                contentItem: Text {
                    text: "📋 复制"
                    color: theme.green
                    font.pixelSize: cfg.fontSmall
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
                background: Rectangle {
                    radius: 6
                    color: parent.hovered
                        ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
                        : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.35)
                }
                onClicked: root.copyItemText()
            }

            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: cfg.compactControlHeight
                flat: true
                enabled: !actionProc.running
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
                        : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.35)
                }
                onClicked: root.requestEdit()
            }

            Button {
                Layout.preferredWidth: 52
                Layout.minimumWidth: 52
                Layout.maximumWidth: 52
                Layout.preferredHeight: cfg.compactControlHeight
                flat: true
                enabled: !actionProc.running
                contentItem: Text {
                    text: root.deleteArmed ? "确认" : "🗑"
                    color: theme.red
                    font.pixelSize: cfg.fontSmall
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 6
                    color: root.deleteArmed
                        ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.24)
                        : parent.hovered
                            ? Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.16)
                            : Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.08)
                    border.width: root.deleteArmed ? 1 : 0
                    border.color: Qt.rgba(theme.red.r, theme.red.g, theme.red.b, 0.65)
                }
                onClicked: root.requestDelete()
                ToolTip.text: root.deleteArmed ? "再次点击确认删除" : "删除"
                ToolTip.visible: hovered
                ToolTip.delay: 400
            }
        }
    }

    Popup {
        id: imagePreview
        parent: root.contentItem
        x: 0
        y: 0
        width: root.width
        height: root.height
        modal: true
        focus: true
        padding: 0
        closePolicy: Popup.CloseOnEscape

        onOpened: contentItem.forceActiveFocus()
        onClosed: {
            root.previewImageIndex = -1;
            if (root.previewOnly) {
                Qt.callLater(function() {
                    root.close();
                    root.previewOnly = false;
                });
            } else {
                root.contentItem.forceActiveFocus();
            }
        }

        background: Rectangle {
            color: Qt.rgba(
                theme.crust.r,
                theme.crust.g,
                theme.crust.b,
                root.previewOnly ? 1.0 : 0.88
            )
            radius: 12
        }

        contentItem: Item {
            focus: true

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    imagePreview.close();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                    root.nextPreviewImage();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                    root.prevPreviewImage();
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: imagePreview.close()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root.currentPreviewName()
                        color: theme.text
                        font.pixelSize: cfg.fontSmall
                        elide: Text.ElideMiddle
                        Layout.fillWidth: true
                    }

                    Text {
                        text: root.previewImages.length > 1 ? ((root.previewImageIndex + 1) + " / " + root.previewImages.length) : ""
                        color: theme.subtext1
                        font.pixelSize: cfg.fontTiny
                        visible: root.previewImages.length > 1
                    }

                    Button {
                        flat: true
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        onClicked: imagePreview.close()
                        contentItem: Text {
                            text: "✕"
                            color: theme.subtext1
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
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    MouseArea {
                        anchors.fill: parent
                        onClicked: mouse.accepted = true
                    }

                    Image {
                        anchors.fill: parent
                        source: root.currentPreviewSource()
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: true
                    }

                    Button {
                        visible: root.previewImages.length > 1
                        flat: true
                        width: 36
                        height: 48
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.prevPreviewImage()
                        contentItem: Text {
                            text: "‹"
                            color: theme.text
                            font.pixelSize: cfg.fontXl
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: parent.hovered
                                ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.55)
                                : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.35)
                        }
                    }

                    Button {
                        visible: root.previewImages.length > 1
                        flat: true
                        width: 36
                        height: 48
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: root.nextPreviewImage()
                        contentItem: Text {
                            text: "›"
                            color: theme.text
                            font.pixelSize: cfg.fontXl
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: 6
                            color: parent.hovered
                                ? Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.55)
                                : Qt.rgba(theme.surface0.r, theme.surface0.g, theme.surface0.b, 0.35)
                        }
                    }
                }
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
            panel.showToast("✅ 操作成功", "success");
            if (t) panel.reloadData(t);
        }
    }

    function runAction(cmd, reloadType) {
        if (!itemData.id) return;
        if (actionProc.running) {
            panel.showToast("⏳ 操作进行中...");
            return;
        }
        pendingReload = reloadType;
        actionProc.command = StarcatchCommands.todoActionCommand(
            cfg.starcatchPath, cmd, itemData.id
        );
        actionProc.running = true;
    }
}
