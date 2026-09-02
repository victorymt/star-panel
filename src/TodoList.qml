import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import "ListNavigation.js" as ListNavigation

/// TodoList — 待办列表组件
Item {
    id: root

    property var items: []
    property bool loading: false
    property string filterStatus: cfg.todoFilter
    // Project filter uses the same three-state contract as Config:
    // "" = all projects, null = unassigned, string = named project.
    // It is intentionally local to the already-fetched todo list.
    property var filterProject: cfg.todoProjectFilter
    readonly property var colors: theme
    property string searchText: ""
    property bool searchActive: searchField.activeFocus
    readonly property string itemType: "todo"
    readonly property alias detailPopupControl: detailPopup
    readonly property alias editPopupControl: editPopup
    readonly property alias currentIndex: listView.currentIndex

    // vim gg/dd/gt 状态机
    property bool _pendingG: false
    property bool _pendingD: false

    // 当前高亮项 id —— 用于 model 替换（改状态/30s 刷新）后还原高亮位置
    property string currentItemId: ""
    // 最近一次导航到的 index 快照 —— Qt 在 JS 数组 model 替换时会把
    // currentIndex 重置为 -1，故不能用 onModelChanged 时的 currentIndex，
    // 必须用导航时快照的 lastIndex 作 fallback。
    property int lastIndex: 0

    // The data source starts with an empty array before the first CLI request.
    // Track that a fetch has actually started so a persisted project is not
    // cleared during component initialization; validate it after the first
    // successful items replacement instead.
    property bool _todoFetchObserved: false
    property bool _todoDataLoaded: false
    property bool _projectValidationScheduled: false

    function normalizeProjectValue(value) {
        if (value === null) return null;
        if (typeof value !== "string") return "";
        return value.trim();
    }

    function normalizeItemProject(value) {
        if (typeof value !== "string") return null;
        var normalized = value.trim();
        return normalized ? normalized : null;
    }

    function projectFilterEquals(left, right) {
        return normalizeProjectValue(left) === normalizeProjectValue(right);
    }

    function setProjectFilter(value) {
        var next = normalizeProjectValue(value);
        if (!projectFilterEquals(root.filterProject, next))
            root.filterProject = next;
        if (cfg.settingsLoaded && !projectFilterEquals(cfg.todoProjectFilter, next)) {
            cfg.todoProjectFilter = next;
            cfg.saveSettings();
        }
    }

    function hasNamedProject(project) {
        var selected = normalizeProjectValue(project);
        if (selected === "" || selected === null) return false;
        var all = items || [];
        for (var i = 0; i < all.length; i++) {
            if (normalizeItemProject(all[i] && all[i].project) === selected)
                return true;
        }
        return false;
    }

    function validateProjectFilter() {
        if (!root._todoDataLoaded || !cfg.settingsLoaded) return;
        var selected = normalizeProjectValue(root.filterProject);
        // Keep the explicit unassigned option even when no such todo exists;
        // it remains a valid persisted choice and has a useful empty state.
        if (typeof selected === "string" && selected !== ""
                && !root.hasNamedProject(selected)) {
            root.setProjectFilter("");
        }
    }

    // projectOptions depends on filterProject.  Defer validation until the
    // current binding evaluation/notification has settled; changing the
    // dependency synchronously from onProjectOptionsChanged causes a QML
    // binding-loop warning when a refresh removes the selected project.
    function scheduleProjectFilterValidation() {
        if (root._projectValidationScheduled) return;
        root._projectValidationScheduled = true;
        Qt.callLater(function() {
            root.validateProjectFilter();
            root._projectValidationScheduled = false;
        });
    }

    Component.onCompleted: {
        // Fetch observation is set by the loading binding before items arrive.
        root.scheduleProjectFilterValidation();
    }

    onLoadingChanged: {
        if (loading) root._todoFetchObserved = true;
    }

    onItemsChanged: {
        if (!root._todoFetchObserved) return;
        root._todoDataLoaded = true;
        root.scheduleProjectFilterValidation();
    }

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
        detailPopup.type = "todo";
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
        var deletedIndex = listView.currentIndex >= 0 ? listView.currentIndex : root.lastIndex;
        if (item && item.id) {
            panel.deleteItem(root.itemType, item.id, function() {
                // The deleted id cannot be restored; keep its pre-delete row as the fallback.
                root.currentItemId = "";
                root.lastIndex = deletedIndex;
            });
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

    function runTodoAction(cmd) {
        var item = currentItem();
        if (!item || !item.id) { panel.showToast("📭 列表为空"); return; }
        detailPopup.type = "todo";
        detailPopup.itemData = item;
        detailPopup.runAction(cmd, "todo");
    }

    function toggleCurrentTodoDone() {
        var item = currentItem();
        if (!item || !item.id) { panel.showToast("📭 列表为空"); return; }
        runTodoAction(item.rawStatus === "Pending" ? "done" : "reopen");
    }

    function archiveCurrentTodo() {
        var item = currentItem();
        if (!item || !item.id) { panel.showToast("📭 列表为空"); return; }
        if (item.rawStatus === "Archived") {
            panel.showToast("📦 已归档");
            return;
        }
        runTodoAction("archive");
    }

    function moveByRows(delta) {
        if (listView.model.length === 0) return;
        listView.currentIndex = ListNavigation.moveIndex(
            listView.currentIndex, delta, listView.model.length
        );
        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain);
        root._trackCurrent();
    }

    function movePage(direction, fraction) {
        var rows = ListNavigation.pageRowCount(listView.height, 56, fraction);
        moveByRows(direction * rows);
    }

    // 快照当前高亮项的 id 与 index。在每次导航与 onModelChanged 还原后调用，
    // 早于任何 model 替换，避开 Qt 重置与 delegate 重建竞态。
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

    // 过滤后的列表（状态 + 项目 + 搜索）
    // 项目选项从全部待办动态生成（而不是当前状态筛选结果），这样切换
    // Pending/Done/Archived 时项目下拉菜单仍保持完整且稳定。未分类固定保留，
    // 使已保存的 null 选择在首次加载和空列表时也能恢复。
    readonly property var projectOptions: {
        var names = [];
        var all = items || [];
        for (var i = 0; i < all.length; i++) {
            var value = root.normalizeItemProject(all[i] && all[i].project);
            if (value !== null && names.indexOf(value) < 0)
                names.push(value);
        }
        // Keep a persisted named value visible until the first real data set
        // arrives; otherwise the ComboBox briefly jumps to “all projects”.
        var selected = root.normalizeProjectValue(root.filterProject);
        if (!root._todoDataLoaded && typeof selected === "string"
                && selected !== "" && names.indexOf(selected) < 0) {
            names.push(selected);
        }
        names.sort();

        var options = [{ kind: "all", value: "", label: "📁 全部项目" }];
        for (var n = 0; n < names.length; n++) {
            options.push({ kind: "named", value: names[n], label: "📁 " + names[n] });
        }
        options.push({ kind: "unassigned", value: null, label: "📁 未分类" });
        return options;
    }

    function projectOptionIndex(project) {
        var selected = normalizeProjectValue(project);
        for (var i = 0; i < projectOptions.length; i++) {
            var option = projectOptions[i];
            if (selected === null && option.kind === "unassigned") return i;
            if (selected === "" && option.kind === "all") return i;
            if (typeof selected === "string" && selected !== ""
                    && option.kind === "named" && option.value === selected)
                return i;
        }
        return -1;
    }

    readonly property var filteredItems: {
        var all = items || [];
        var statusFiltered = all.filter(function(item) {
            return item.rawStatus === filterStatus;
        });
        var selectedProject = root.normalizeProjectValue(filterProject);
        var projectFiltered = statusFiltered;
        if (selectedProject === null) {
            projectFiltered = statusFiltered.filter(function(item) {
                return root.normalizeItemProject(item && item.project) === null;
            });
        } else if (selectedProject !== "") {
            projectFiltered = statusFiltered.filter(function(item) {
                return root.normalizeItemProject(item && item.project) === selectedProject;
            });
        }
        if (!searchText.trim()) return projectFiltered;
        var q = searchText.trim().toLowerCase();
        return projectFiltered.filter(function(item) {
            return (item.title && item.title.toLowerCase().indexOf(q) >= 0)
                || (item.description && item.description.toLowerCase().indexOf(q) >= 0);
        });
    }

    // If a completed refresh removes the selected named project, fall back to
    // all projects. The _todoDataLoaded guard avoids clearing persisted state
    // while the initial request is still in flight.
    onProjectOptionsChanged: {
        root.scheduleProjectFilterValidation();
    }

    onFilterStatusChanged: {
        if (cfg.todoFilter !== filterStatus) {
            cfg.todoFilter = filterStatus;
            cfg.saveSettings();
        }
    }

    onFilterProjectChanged: {
        if (!cfg.settingsLoaded) return;
        var selected = root.normalizeProjectValue(filterProject);
        if (!root.projectFilterEquals(cfg.todoProjectFilter, selected)) {
            cfg.todoProjectFilter = selected;
            cfg.saveSettings();
        }
    }

    // 外部（如设置面板"恢复默认"）修改 cfg.todoFilter 时，推回本地 filterStatus，
    // 否则一旦用户点过过滤芯片，本地赋值会断开初始绑定，UI 就不再跟随。
    Connections {
        target: cfg
        function onTodoFilterChanged() {
            if (root.filterStatus !== cfg.todoFilter) {
                root.filterStatus = cfg.todoFilter;
            }
        }
        function onTodoProjectFilterChanged() {
            var selected = root.normalizeProjectValue(cfg.todoProjectFilter);
            if (!root.projectFilterEquals(root.filterProject, selected))
                root.filterProject = selected;
        }
        function onSettingsLoadedChanged() {
            root.scheduleProjectFilterValidation();
        }
    }

    // ── 过滤器栏（chips + 搜索框，两行布局，与 Idea/Log 对齐） ──
    ColumnLayout {
        id: filterBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        property var filters: [
            { label: "⬜ 待办",   status: "Pending" },
            { label: "✅ 已完成", status: "Done" },
            { label: "📦 已归档", status: "Archived" }
        ]

        // 第一行：过滤 chips
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: filterBar.filters

                delegate: Button {
                    required property var modelData
                    required property int index

                    flat: true
                    onClicked: root.filterStatus = modelData.status
                    Layout.preferredWidth: implicitWidth

                    contentItem: Text {
                        text: modelData.label
                        color: root.filterStatus === modelData.status ? colors.text : colors.subtext1
                        font.pixelSize: cfg.fontSmall
                        font.bold: root.filterStatus === modelData.status
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        radius: 6
                        color: root.filterStatus === modelData.status
                            ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.5)
                            : parent.hovered || parent.visualFocus
                                ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.25)
                                : "transparent"
                    }
                }
            }

            Item { Layout.fillWidth: true }
        }

        // 第二行：项目筛选（项目名来自当前已加载的全部待办）
        ComboBox {
            id: projectCombo
            Layout.fillWidth: true
            Layout.preferredHeight: cfg.compactControlHeight
            model: root.projectOptions
            textRole: "label"
            KeyNavigation.tab: searchField
            KeyNavigation.backtab: filterBar

            Component.onCompleted: {
                currentIndex = Math.max(0, root.projectOptionIndex(root.filterProject));
            }

            Connections {
                target: root
                function onFilterProjectChanged() {
                    var index = root.projectOptionIndex(root.filterProject);
                    projectCombo.currentIndex = index < 0 ? 0 : index;
                }
                function onProjectOptionsChanged() {
                    var index = root.projectOptionIndex(root.filterProject);
                    projectCombo.currentIndex = index;
                }
            }

            onActivated: {
                var option = root.projectOptions[currentIndex];
                root.setProjectFilter(option ? option.value : "");
            }

            contentItem: Text {
                text: projectCombo.currentIndex >= 0
                    && projectCombo.currentIndex < root.projectOptions.length
                    ? root.projectOptions[projectCombo.currentIndex].label : "📁 全部项目"
                color: colors ? colors.text : "#cdd6f4"
                font.pixelSize: cfg.fontSmall
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }

            background: Rectangle {
                radius: 6
                color: projectCombo.hovered
                    ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.4)
                    : Qt.rgba(colors.surface0.r, colors.surface0.g, colors.surface0.b, 0.3)
                border.width: projectCombo.visualFocus ? 1 : 0
                border.color: colors ? Qt.rgba(colors.blue.r, colors.blue.g, colors.blue.b, 0.3) : "transparent"
            }

            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: projectCombo.width
                // ComboBox does not automatically forward highlightedIndex to
                // custom delegates; keep keyboard navigation visibly focused.
                highlighted: projectCombo.highlightedIndex === index

                contentItem: Text {
                    text: modelData.label
                    color: projectCombo.currentIndex === index
                        ? (colors ? colors.text : "#cdd6f4")
                        : (colors ? colors.subtext0 : "#a6adc8")
                    font.pixelSize: cfg.fontSmall
                    font.bold: projectCombo.currentIndex === index
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    color: highlighted
                        ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.4)
                        : "transparent"
                }
            }

            popup: Popup {
                y: projectCombo.height
                width: projectCombo.width
                implicitHeight: Math.min(contentItem.implicitHeight + padding * 2, 260)
                padding: 4

                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: projectCombo.popup.visible ? projectCombo.delegateModel : null
                    // Follow the highlighted option so a long project list
                    // scrolls as the user presses Up/Down.
                    currentIndex: projectCombo.highlightedIndex
                    highlightRangeMode: ListView.ApplyRange
                    highlightMoveDuration: 0

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                    }
                }

                background: Rectangle {
                    radius: 8
                    color: colors ? Qt.rgba(colors.base.r, colors.base.g, colors.base.b, 0.96) : "#1e1e2e"
                    border.width: 1
                    border.color: colors ? Qt.rgba(colors.surface1.r, colors.surface1.g, colors.surface1.b, 0.4) : "#45475a"
                }
            }

            indicator: Text {
                text: "▾"
                color: colors ? colors.subtext0 : "#a6adc8"
                font.pixelSize: cfg.fontTiny
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // 第三行：搜索框（占满宽度，与 IdeaList/LogList 一致）
        TextField {
            id: searchField
            Layout.fillWidth: true
            Layout.preferredHeight: cfg.compactControlHeight
            placeholderText: "🔍 搜索"
            placeholderTextColor: colors ? colors.subtext1 : "#a6adc8"
            color: colors ? colors.text : "#cdd6f4"
            font.pixelSize: cfg.fontSmall
            verticalAlignment: Text.AlignVCenter
            leftPadding: 6
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
            KeyNavigation.backtab: projectCombo

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
                var selectedProject = root.normalizeProjectValue(filterProject);
                var projectLabel = selectedProject === null ? "未分类" : selectedProject;
                if (searchText.trim() && selectedProject !== "")
                    return "🔍 项目「" + projectLabel + "」没有匹配的结果";
                if (searchText.trim()) return "🔍 没有匹配的结果";
                if (items.length === 0) return "✨ 暂无待办\n一切都在掌控之中~";
                if (selectedProject !== "")
                    return "📁 项目「" + projectLabel + "」没有待办任务";
                if (filterStatus === "Pending") return "⬜ 没有待办任务";
                if (filterStatus === "Done") return "✅ 没有已完成任务";
                return "📦 没有已归档任务";
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
            mid: colors ? colors.blue : "#89b4fa"
        }
    }

    // ── 待办列表 ──
    ListView {
        id: listView
        anchors.top: filterBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 8
        visible: true
        model: root.filteredItems
        clip: true
        spacing: 4
        focus: true
        currentIndex: 0
        // 保留滚动位置与高亮项：model 替换（改状态 / 30s 刷新 / 搜索）时
        // 按 id 还原 currentIndex，避免高亮跳回顶部打断阅读/操作。
        // 若该项已被过滤掉（如「待办」视图标记完成），保持原位并 clamp，
        // 高亮自然落到下一项。
        onModelChanged: {
            var savedY = contentY;
            var targetId = root.currentItemId;
            var oldIndex = root.lastIndex;
            Qt.callLater(function() {
                currentIndex = ListNavigation.restoreIndex(model, targetId, oldIndex);
                if (savedY <= contentHeight - height + spacing)
                    contentY = savedY;
                else
                    contentY = Math.max(0, contentHeight - height);
                positionViewAtIndex(currentIndex, ListView.Contain);
                // 还原后快照新当前项，供下次 reload 使用（首次加载也由此初始化 id）
                root._trackCurrent();
            });
        }

        KeyNavigation.tab: searchField
        KeyNavigation.backtab: searchField

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                // 弹窗可见时关弹窗（焦点没进弹窗的兜底）；否则不消费，交由全局 Shortcut 关面板
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
            } else if (event.key === Qt.Key_1 && !event.modifiers) {
                // 1/2/3 — 切 Todo 过滤器（与 Ctrl+1/2/3 切 tab 不冲突）
                root.filterStatus = "Pending";
                event.accepted = true;
            } else if (event.key === Qt.Key_2 && !event.modifiers) {
                root.filterStatus = "Done";
                event.accepted = true;
            } else if (event.key === Qt.Key_3 && !event.modifiers) {
                root.filterStatus = "Archived";
                event.accepted = true;
            } else if (event.key === Qt.Key_Space && !event.modifiers) {
                // Space — Pending 标记完成，Done/Archived 恢复待办。
                root.toggleCurrentTodoDone();
                event.accepted = true;
            } else if (event.key === Qt.Key_A && !event.modifiers) {
                // a — 归档当前待办。
                root.archiveCurrentTodo();
                event.accepted = true;
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down
                || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_N)) {
                // j / ↓ / Ctrl+N — 下移
                root.moveByRows(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up
                       || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_P)) {
                // k / ↑ / Ctrl+P — 上移
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
                // gg — 跳到顶部（500ms 内按两次 g 才算 gg）
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
                // G — 跳到底部
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
                // o — 聚焦快速输入（"open new line" → insert mode）
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
                // dd — 删除当前项（2.5s 内按两次 d 确认，与 toast 时长对齐）
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
            implicitHeight: Math.max(48, contentRow.implicitHeight + 16)
            highlighted: ListView.isCurrentItem

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Space && !event.modifiers) {
                    listView.currentIndex = index;
                    root._trackCurrent();
                    root.toggleCurrentTodoDone();
                    event.accepted = true;
                } else if (event.key === Qt.Key_A && !event.modifiers) {
                    listView.currentIndex = index;
                    root._trackCurrent();
                    root.archiveCurrentTodo();
                    event.accepted = true;
                }
            }

            contentItem: RowLayout {
                id: contentRow
                spacing: 8

                // 优先级指示器
                Rectangle {
                    width: 6
                    height: parent.height
                    radius: 2
                    color: {
                        switch (modelData.priority) {
                            case "🔴": return colors ? colors.red : "#f38ba8";
                            case "🟡": return colors ? colors.peach : "#fab387";
                            case "⚪": return colors ? colors.subtext1 : "#a6adc8";
                            default:   return colors ? colors.green : "#a6e3a1";
                        }
                    }
                }

                // 状态图标
                Text {
                    text: modelData.status === "✅" ? "✓" :
                          modelData.status === "📦" ? "📦" : "○"
                    color: colors ? colors.subtext0 : "#a6adc8"
                    font.pixelSize: cfg.fontMedium
                }

                // 标题 + 描述 + 标签
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    RowLayout {
                        spacing: 4
                        Layout.fillWidth: true

                        Text {
                            id: titleText
                            text: modelData.title
                            color: colors ? colors.text : "#cdd6f4"
                            font.pixelSize: cfg.fontBase
                            elide: Text.ElideRight
                            Layout.fillWidth: true

                            // 已完成状态用删除线
                            font.strikeout: modelData.status === "✅"
                            opacity: modelData.status === "✅" ? 0.6 : 1.0
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

                    Text {
                        text: modelData.description || ""
                        color: colors ? colors.subtext0 : "#a6adc8"
                        font.pixelSize: cfg.fontBase
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        visible: modelData.description && modelData.description !== ""
                        opacity: modelData.status === "✅" ? 0.5 : 0.85
                    }

                    // 标签
                    TagList {
                        tags: modelData.tags
                        tagColor: colors ? colors.sapphire : "#74c7ec"
                    }
                }

                // 截止日期
                Text {
                    text: panel.getDueText(modelData.due)
                    color: panel.getDueColor(modelData.due, colors)
                    font.pixelSize: cfg.fontSmall
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
                detailPopup.type = "todo";
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
