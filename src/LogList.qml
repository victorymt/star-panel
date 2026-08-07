import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// LogList — 日志列表组件
Item {
    id: root

    property var items: []
    property bool loading: false
    readonly property var colors: theme
    property string searchText: ""
    property bool searchActive: searchField.activeFocus
    property int filterDays: 3
    readonly property string itemType: "log"
    readonly property alias detailPopupControl: detailPopup
    readonly property alias editPopupControl: editPopup
    readonly property int maxInlineImages: 3
    readonly property int inlineThumbnailWidth: 64
    readonly property int inlineThumbnailHeight: 48

    // vim gg/dd/gt 状态机
    property bool _pendingG: false
    property bool _pendingD: false
    property bool _timeFilterReady: false

    // 当前高亮项 id —— 用于 model 替换后还原高亮位置
    property string currentItemId: ""
    // 导航时快照的 index —— Qt 在 JS 数组 model 替换时重置 currentIndex，
    // 故 onModelChanged 的 fallback 必须用此快照而非当时的 currentIndex。
    property int lastIndex: 0

    function focusSearch() { searchField.forceActiveFocus(); }
    function focusList() { listView.forceActiveFocus(); }

    function currentItem() {
        var m = listView.model;
        var i = listView.currentIndex;
        return (i >= 0 && i < m.length) ? m[i] : null;
    }

    function openCurrentItem() {
        var item = currentItem();
        if (!item) { panel.showToast("📭 列表为空"); return; }
        detailPopup.type = "log";
        detailPopup.itemData = item;
        detailPopup.open();
    }

    function editCurrentItem() {
        var item = currentItem();
        if (item && item.id) editPopup.openEdit(root.itemType, item.id);
        else panel.showToast("📭 列表为空");
    }

    function deleteCurrentItem() {
        var item = currentItem();
        if (item && item.id) {
            panel.deleteItem(root.itemType, item.id);
            panel.showToast("🗑️ 删除中...");
        } else {
            panel.showToast("⚠️ 该项没有 id，无法删除");
        }
    }

    function copyCurrentItem() {
        var item = currentItem();
        if (!item) { panel.showToast("📭 列表为空"); return; }
        panel.copyItem(root.itemType, item);
    }

    function moveByRows(delta) {
        if (listView.model.length === 0) return;
        listView.currentIndex = Math.max(0, Math.min(listView.model.length - 1, listView.currentIndex + delta));
        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
        root._trackCurrent();
    }

    function movePage(direction, fraction) {
        var currentHeight = listView.currentItem ? listView.currentItem.height + listView.spacing : 56;
        var rows = Math.max(1, Math.floor((listView.height / Math.max(1, currentHeight)) * fraction));
        moveByRows(direction * rows);
    }

    function inlineImages(images) {
        return (images || []).slice(0, root.maxInlineImages);
    }

    function hiddenImageCount(images) {
        return Math.max(0, (images || []).length - root.maxInlineImages);
    }

    function _trackCurrent() {
        var m = listView.model;
        var i = listView.currentIndex;
        if (i >= 0 && i < m.length && m[i]) {
            root.currentItemId = m[i].id || "";
            root.lastIndex = i;
        }
    }

    // gg 第二次 g 的超时（1s 内按第二次 g 才算 gg，对齐 vim 默认 timeoutlen）
    Timer { id: gReset; interval: 1000; onTriggered: root._pendingG = false }
    // dd 第二次 d 的超时（2.5s 内按第二次 d 才算 dd，与 toast 时长对齐）
    Timer { id: dReset; interval: 2500; onTriggered: root._pendingD = false }

    Component.onCompleted: {
        root._timeFilterReady = true;
        var days = cfg.normalizeLogFilterDays(cfg.logFilterDays);
        if (root.filterDays !== days) {
            root.filterDays = days;
            panel.reloadData(root.itemType);
        }
    }

    onFilterDaysChanged: {
        var days = cfg.normalizeLogFilterDays(filterDays);
        if (filterDays !== days) {
            filterDays = days;
            return;
        }
        if (cfg.logFilterDays !== days) {
            cfg.logFilterDays = days;
            cfg.saveSettings();
            if (root._timeFilterReady) panel.reloadData(root.itemType);
        }
    }

    Connections {
        target: cfg
        function onLogFilterDaysChanged() {
            var days = cfg.normalizeLogFilterDays(cfg.logFilterDays);
            if (root.filterDays === days) return;
            root.filterDays = days;
            if (root._timeFilterReady) panel.reloadData(root.itemType);
        }
    }

    // 过滤后的列表（搜索）—— 与 listView.model 同源，供空状态判断使用
    readonly property var filteredItems: {
        var all = items || [];
        if (!searchText.trim()) return all;
        var q = searchText.trim().toLowerCase();
        return all.filter(function(item) {
            return (item.content && item.content.toLowerCase().indexOf(q) >= 0)
                || (item.title && item.title.toLowerCase().indexOf(q) >= 0)
                || ((item.images || []).join(" ").toLowerCase().indexOf(q) >= 0);
        });
    }

    // ── 过滤器栏（时间范围 + 搜索）──
    ColumnLayout {
        id: filterBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        property var filters: [
            { label: "今天", days: 1 },
            { label: "近 3 天", days: 3 },
            { label: "近 7 天", days: 7 },
            { label: "近 30 天", days: 30 }
        ]

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: filterBar.filters

                delegate: Button {
                    required property var modelData
                    required property int index

                    flat: true
                    onClicked: root.filterDays = modelData.days
                    Layout.preferredWidth: implicitWidth

                    contentItem: Text {
                        text: modelData.label
                        color: root.filterDays === modelData.days ? colors.text : colors.subtext1
                        font.pixelSize: cfg.fontSmall
                        font.bold: root.filterDays === modelData.days
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 6
                        color: root.filterDays === modelData.days
                            ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.5)
                            : parent.hovered || parent.visualFocus
                                ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.25)
                                : "transparent"
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        TextField {
            id: searchField
            Layout.fillWidth: true
            Layout.preferredHeight: cfg.compactControlHeight
            placeholderText: "🔍 搜索日志..."
            placeholderTextColor: colors ? colors.subtext1 : "#a6adc8"
            color: colors ? colors.text : "#cdd6f4"
            font.pixelSize: cfg.fontSmall
            verticalAlignment: Text.AlignVCenter
            rightPadding: clearBtn.visible ? cfg.compactControlHeight : 6
            background: Rectangle {
                radius: 6
                color: searchField.activeFocus
                    ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.4)
                    : Qt.rgba(colors.surface0.r, colors.surface0.g, colors.surface0.b, 0.3)
                border.width: searchField.activeFocus ? 1 : 0
                border.color: searchField.activeFocus
                    ? Qt.rgba(colors.blue.r, colors.blue.g, colors.blue.b, 0.3)
                    : "transparent"
            }
            onTextChanged: root.searchText = text

            KeyNavigation.tab: listView
            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    if (searchField.text !== "") {
                        searchField.text = "";
                    } else {
                        searchField.focus = false;
                        listView.forceActiveFocus();
                    }
                    panel.switchToEnglishIme();
                    event.accepted = true;
                } else if (panel.handleEmacsEdit(searchField, event)) {
                    return;
                }
            }

            Text {
                id: clearBtn
                text: "✕"
                color: colors ? colors.subtext1 : "#a6adc8"
                font.pixelSize: cfg.fontSmall
                width: cfg.compactControlHeight
                height: parent.height
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text !== ""
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                MouseArea {
                    anchors.fill: parent
                    onClicked: { searchField.text = ""; searchField.focus = false; }
                }
            }
        }
    }

    // ── 空状态 ──
    Rectangle {
        anchors.top: filterBar.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !loading && filteredItems.length === 0
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: {
                if (searchText.trim()) return "🔍 没有匹配的结果";
                if (filterDays === 1) return "📓 今天暂无日志\n随手记下此刻吧~";
                return "📓 近 " + filterDays + " 天暂无日志";
            }
            color: colors ? colors.subtext1 : "#a6adc8"
            font.pixelSize: cfg.fontMedium
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.6
        }
    }

    // ── 加载状态 ──
    BusyIndicator {
        anchors.centerIn: parent
        visible: loading && items.length === 0
        running: visible
        palette {
            mid: colors ? colors.peach : "#fab387"
        }
    }

    // ── 日志列表 ──
    ListView {
        id: listView
        anchors.top: filterBar.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: true
        model: root.filteredItems
        clip: true
        spacing: 4
        focus: true
        currentIndex: 0
        // 保留滚动位置与高亮项：model 替换时按 id 还原 currentIndex，
        // 找不到则保持原位并 clamp，高亮自然落到下一项。
        onModelChanged: {
            var savedY = contentY;
            var targetId = root.currentItemId;
            var oldIndex = root.lastIndex;
            Qt.callLater(function() {
                var idx = -1;
                for (var i = 0; i < model.length; i++) {
                    if (model[i] && model[i].id === targetId) { idx = i; break; }
                }
                if (idx >= 0) {
                    currentIndex = idx;
                } else if (oldIndex >= model.length) {
                    currentIndex = Math.max(0, model.length - 1);
                } else {
                    currentIndex = oldIndex;
                }
                if (savedY <= contentHeight - height + spacing)
                    contentY = savedY;
                else
                    contentY = Math.max(0, contentHeight - height);
                positionViewAtIndex(currentIndex, ListView.Contain);
                root._trackCurrent();
            });
        }

        KeyNavigation.tab: searchField
        KeyNavigation.backtab: searchField

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                if (detailPopup.visible) {
                    detailPopup.close();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Q && !event.modifiers) {
                // q — vim :q 等价，关弹窗或关面板（Ctrl+G 在 Qt6.11/Wayland 被吞，用 q 替代）
                panel.closeTopOrSelf();
                event.accepted = true;
            } else if (event.key === Qt.Key_H && !event.modifiers) {
                panel.switchTab(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_L && !event.modifiers) {
                panel.switchTab(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Colon && !event.modifiers) {
                // : — vim 进命令模式（交给 QuickInput 处理）
                quickInput.enterCommandMode();
                event.accepted = true;
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down
                || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_N)) {
                root.moveByRows(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up
                       || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_P)) {
                root.moveByRows(-1);
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_D) {
                root.movePage(1, 0.5);
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_U) {
                root.movePage(-1, 0.5);
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_F) {
                root.movePage(1, 1.0);
                event.accepted = true;
            } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_B) {
                root.movePage(-1, 1.0);
                event.accepted = true;
            } else if (event.key === Qt.Key_G && !(event.modifiers & Qt.ShiftModifier)) {
                if (root._pendingG) {
                    currentIndex = 0;
                    positionViewAtIndex(0, ListView.Beginning);
                    root._trackCurrent();
                    root._pendingG = false;
                    gReset.stop();
                } else {
                    root._pendingG = true;
                    gReset.restart();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) {
                if (model.length > 0) {
                    currentIndex = model.length - 1;
                    positionViewAtIndex(currentIndex, ListView.End);
                    root._trackCurrent();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_T) {
                // gt / gT — vim 风格切换 tab（仅在 _pendingG 即第一次 g 之后触发）
                if (root._pendingG) {
                    root._pendingG = false;
                    gReset.stop();
                    panel.switchTab(event.modifiers & Qt.ShiftModifier ? -1 : 1);
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_O && !event.modifiers) {
                quickInput.focusInput();
                event.accepted = true;
            } else if (event.key === Qt.Key_R && !event.modifiers) {
                panel.reloadData(root.itemType);
                panel.showToast("🔄 刷新当前列表...");
                event.accepted = true;
            } else if (event.key === Qt.Key_R && (event.modifiers & Qt.ShiftModifier)) {
                panel.reloadData();
                panel.showToast("🔄 刷新中...");
                event.accepted = true;
            } else if (event.key === Qt.Key_D && !event.modifiers) {
                if (root._pendingD) {
                    root._pendingD = false;
                    dReset.stop();
                    root.deleteCurrentItem();
                } else if (model.length === 0) {
                    panel.showToast("📭 列表为空");
                } else {
                    root._pendingD = true;
                    dReset.restart();
                    panel.showToast("再按 d 确认删除");
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_E && !event.modifiers) {
                // e — 编辑当前项（vim 风格）
                root.editCurrentItem();
                event.accepted = true;
            } else if (event.key === Qt.Key_Y && !event.modifiers) {
                // y — 复制当前项到剪切板（vim yank）
                root.copyCurrentItem();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                root.openCurrentItem();
                event.accepted = true;
            }
        }

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: ItemDelegate {
            id: itemDel
            required property var modelData
            required property int index

            width: ListView.view.width
            implicitHeight: Math.max(56, itemContent.implicitHeight + 16)
            highlighted: ListView.isCurrentItem

            contentItem: RowLayout {
                id: itemContent
                spacing: 10

                ColumnLayout {
                    id: contentColumn
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        text: modelData.content || ""
                        color: colors ? colors.text : "#cdd6f4"
                        font.pixelSize: cfg.fontBase
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        maximumLineCount: 2
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        Text {
                            text: {
                                var title = modelData.title || "";
                                var count = (modelData.images || []).length;
                                return count > 0 ? title + " · 📎 " + count : title;
                            }
                            color: colors ? colors.subtext1 : "#a6adc8"
                            font.pixelSize: cfg.fontTiny
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        EntryQuickActions {
                            revealed: itemDel.hovered
                            editColor: colors ? colors.blue : "#89b4fa"
                            copyColor: colors ? colors.green : "#a6e3a1"
                            hoverColor: colors ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.55) : "#45475a"
                            iconSize: cfg.fontSmall
                            onEditRequested: {
                                listView.currentIndex = itemDel.index;
                                root._trackCurrent();
                                root.editCurrentItem();
                            }
                            onCopyRequested: {
                                listView.currentIndex = itemDel.index;
                                root._trackCurrent();
                                root.copyCurrentItem();
                            }
                        }
                    }

                    // 标签
                    TagList {
                        tags: modelData.tags
                        tagColor: colors ? colors.sapphire : "#74c7ec"
                    }
                }

                // 每条日志右侧的缩略图与条目内容等高；点击后直接进入对应大图预览。
                Item {
                    id: inlineThumbnailArea
                    readonly property int visibleImageCount: Math.min(
                        (itemDel.modelData.images || []).length,
                        root.maxInlineImages
                    )
                    readonly property bool hasOverflow: (itemDel.modelData.images || []).length > root.maxInlineImages
                    readonly property int tileCount: visibleImageCount + (hasOverflow ? 1 : 0)

                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.fillHeight: true
                    Layout.preferredWidth: implicitWidth
                    Layout.minimumWidth: implicitWidth
                    Layout.maximumWidth: implicitWidth
                    implicitWidth: visibleImageCount * root.inlineThumbnailWidth
                        + (hasOverflow ? 46 : 0)
                        + Math.max(0, tileCount - 1) * inlineThumbnailRow.spacing
                    implicitHeight: Math.max(root.inlineThumbnailHeight, contentColumn.implicitHeight)
                    visible: (itemDel.modelData.images || []).length > 0

                    Row {
                        id: inlineThumbnailRow
                        anchors.fill: parent
                        spacing: 6

                        Repeater {
                            model: root.inlineImages(itemDel.modelData.images)

                            delegate: Rectangle {
                                id: thumbnailFrame
                                required property var modelData
                                required property int index

                                width: root.inlineThumbnailWidth
                                height: inlineThumbnailRow.height
                                radius: 6
                                clip: true
                                color: colors ? colors.surface0 : "#313244"
                                border.width: 1
                                border.color: thumbnailMouse.containsMouse
                                    ? (colors ? colors.blue : "#89b4fa")
                                    : (colors ? colors.surface1 : "#45475a")

                                Image {
                                    id: thumbnailImage
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: detailPopup.imageSource(thumbnailFrame.modelData)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: root.inlineThumbnailWidth * 2
                                    sourceSize.height: thumbnailFrame.height * 2
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: thumbnailImage.status === Image.Error
                                    text: "🖼"
                                    color: colors ? colors.subtext1 : "#a6adc8"
                                    font.pixelSize: cfg.fontMedium
                                }

                                MouseArea {
                                    id: thumbnailMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: function(mouse) {
                                        listView.currentIndex = itemDel.index;
                                        root._trackCurrent();
                                        detailPopup.openImage(itemDel.modelData, thumbnailFrame.index);
                                        mouse.accepted = true;
                                    }
                                }

                                ToolTip.visible: thumbnailMouse.containsMouse
                                ToolTip.text: detailPopup.imageName(thumbnailFrame.modelData)
                            }
                        }

                        Rectangle {
                            id: overflowThumbnail
                            readonly property int hiddenCount: root.hiddenImageCount(itemDel.modelData.images)

                            visible: hiddenCount > 0
                            width: 46
                            height: inlineThumbnailRow.height
                            radius: 6
                            color: overflowMouse.containsMouse
                                ? (colors ? Qt.rgba(colors.blue.r, colors.blue.g, colors.blue.b, 0.22) : "#45475a")
                                : (colors ? colors.surface0 : "#313244")
                            border.width: 1
                            border.color: colors ? colors.surface1 : "#45475a"

                            Text {
                                anchors.centerIn: parent
                                text: "+" + overflowThumbnail.hiddenCount
                                color: colors ? colors.blue : "#89b4fa"
                                font.pixelSize: cfg.fontSmall
                                font.bold: true
                            }

                            MouseArea {
                                id: overflowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    listView.currentIndex = itemDel.index;
                                    root._trackCurrent();
                                    detailPopup.openImage(itemDel.modelData, root.maxInlineImages);
                                    mouse.accepted = true;
                                }
                            }
                        }
                    }
                }
            }

            background: Rectangle {
                radius: 8
                color: itemDel.highlighted
                    ? Qt.rgba(colors.surface2.r, colors.surface2.g, colors.surface2.b, 0.5)
                    : hovered
                        ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.3)
                        : "transparent"
                border.width: itemDel.highlighted ? 1 : 0
                border.color: Qt.rgba(colors.blue.r, colors.blue.g, colors.blue.b, 0.6)
            }

            onClicked: {
                listView.currentIndex = index;
                root._trackCurrent();
                detailPopup.type = "log";
                detailPopup.itemData = modelData;
                detailPopup.open();
            }
        }
    }

    DetailPopup {
        id: detailPopup
        onEditRequested: function(itemType, itemId) {
            editPopup.openEdit(itemType, itemId);
        }
    }
    EditPopup { id: editPopup }
}
