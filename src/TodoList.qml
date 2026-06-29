import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// TodoList — 待办列表组件
Item {
    id: root

    property var items: []
    property bool loading: false
    property string filterStatus: cfg.todoFilter
    readonly property var colors: theme
    property string searchText: ""
    property bool searchActive: searchField.activeFocus
    readonly property string itemType: "todo"

    // vim gg/dd 状态机
    property bool _pendingG: false
    property bool _pendingD: false

    function focusSearch() { searchField.forceActiveFocus(); }
    function focusList() { listView.forceActiveFocus(); }

    // gg 第二次 g 的超时（500ms 内按第二次 g 才算 gg）
    Timer { id: gReset; interval: 500; onTriggered: root._pendingG = false }
    // dd 第二次 d 的超时（1.5s 内按第二次 d 才算 dd）
    Timer { id: dReset; interval: 1500; onTriggered: root._pendingD = false }

    // 过滤后的列表（状态 + 搜索）
    readonly property var filteredItems: {
        var all = items || [];
        var statusFiltered = all.filter(function(item) {
            return item.rawStatus === filterStatus;
        });
        if (!searchText.trim()) return statusFiltered;
        var q = searchText.trim().toLowerCase();
        return statusFiltered.filter(function(item) {
            return (item.title && item.title.toLowerCase().indexOf(q) >= 0)
                || (item.description && item.description.toLowerCase().indexOf(q) >= 0);
        });
    }

    onFilterStatusChanged: {
        if (cfg.todoFilter !== filterStatus) {
            cfg.todoFilter = filterStatus;
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
    }

    // ── 过滤器栏（含搜索） ──
    RowLayout {
        id: filterBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 32
        spacing: 4

        property var filters: [
            { label: "⬜ 待办",   status: "Pending" },
            { label: "✅ 已完成", status: "Done" },
            { label: "📦 已归档", status: "Archived" }
        ]

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
                    color: root.filterStatus === modelData.status ? colors.text : colors.overlay0
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

        // 嵌入式搜索框
        TextField {
            id: searchField
            Layout.preferredWidth: 120
            Layout.maximumWidth: 180
            height: 26
            placeholderText: "🔍 搜索"
            placeholderTextColor: colors ? colors.overlay0 : "#6c7086"
            color: colors ? colors.text : "#cdd6f4"
            font.pixelSize: cfg.fontTiny
            verticalAlignment: Text.AlignVCenter
            leftPadding: 6
            rightPadding: clearBtn.visible ? 20 : 6
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
            KeyNavigation.backtab: filterBar

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Escape) {
                    if (searchField.text !== "") {
                        searchField.text = "";
                    } else {
                        searchField.focus = false;
                        listView.forceActiveFocus();
                    }
                    event.accepted = true;
                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_A) {
                    // emacs Ctrl+A — 行首
                    searchField.cursorPosition = 0;
                    event.accepted = true;
                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_E) {
                    // emacs Ctrl+E — 行尾
                    searchField.cursorPosition = searchField.text.length;
                    event.accepted = true;
                }
            }

            Text {
                id: clearBtn
                text: "✕"
                color: colors ? colors.overlay0 : "#6c7086"
                font.pixelSize: cfg.fontTiny
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                visible: searchField.text !== ""
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
                if (items.length === 0) return "✨ 暂无待办\n一切都在掌控之中~";
                if (filterStatus === "Pending") return "⬜ 没有待办任务";
                if (filterStatus === "Done") return "✅ 没有已完成任务";
                return "📦 没有已归档任务";
            }
            color: colors ? colors.overlay0 : "#6c7086"
            font.pixelSize: cfg.fontMedium
            horizontalAlignment: Text.AlignHCenter
            lineHeight: 1.6
        }
    }

    // ── 加载状态 ──
    BusyIndicator {
        anchors.centerIn: parent
        visible: loading
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
        visible: !loading
        model: root.filteredItems
        clip: true
        spacing: 4
        focus: true
        currentIndex: 0
        // 保留滚动位置：model 替换（30s 刷新 / 搜索）时回到原 contentY，
        // 避免列表跳回顶部打断阅读。
        onModelChanged: {
            var savedY = contentY;
            currentIndex = 0;
            Qt.callLater(function() {
                if (savedY <= contentHeight - height + spacing)
                    contentY = savedY;
                else
                    contentY = Math.max(0, contentHeight - height);
            });
        }

        KeyNavigation.tab: searchField
        KeyNavigation.backtab: searchField

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_J || event.key === Qt.Key_Down
                || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_N)) {
                // j / ↓ / Ctrl+N — 下移
                if (currentIndex < model.length - 1) currentIndex++;
                positionViewAtIndex(currentIndex, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up
                       || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_P)) {
                // k / ↑ / Ctrl+P — 上移
                if (currentIndex > 0) currentIndex--;
                positionViewAtIndex(currentIndex, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_G && !(event.modifiers & Qt.ShiftModifier)) {
                // gg — 跳到顶部（500ms 内按两次 g）
                if (root._pendingG) {
                    currentIndex = 0;
                    positionViewAtIndex(0, ListView.Beginning);
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
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_H && !event.modifiers) {
                // h — 上一个 tab
                panel.switchTab(-1);
                event.accepted = true;
            } else if (event.key === Qt.Key_L && !event.modifiers) {
                // l — 下一个 tab
                panel.switchTab(1);
                event.accepted = true;
            } else if (event.key === Qt.Key_O && !event.modifiers) {
                // o — 聚焦快速输入（"open new line" → insert mode）
                quickInput.focusInput();
                event.accepted = true;
            } else if (event.key === Qt.Key_D && !event.modifiers) {
                // dd — 删除当前项（1.5s 内按两次 d 确认）
                if (root._pendingD) {
                    root._pendingD = false;
                    dReset.stop();
                    if (currentIndex >= 0 && currentIndex < model.length && model[currentIndex].id) {
                        panel.deleteItem(root.itemType, model[currentIndex].id);
                    }
                } else {
                    root._pendingD = true;
                    dReset.restart();
                    panel.showToast("再按 d 确认删除");
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (currentIndex >= 0 && currentIndex < model.length) {
                    var item = model[currentIndex];
                    detailPopup.type = "todo";
                    detailPopup.itemData = item;
                    detailPopup.open();
                }
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

            contentItem: RowLayout {
                id: contentRow
                spacing: 8

                // vim 风格当前行指示符 ▸
                Text {
                    text: "▸"
                    color: colors ? colors.blue : "#89b4fa"
                    font.pixelSize: cfg.fontMedium
                    font.bold: true
                    visible: itemDel.highlighted
                    Layout.preferredWidth: 14
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                // 优先级指示器
                Rectangle {
                    width: 6
                    height: parent.height
                    radius: 2
                    color: {
                        switch (modelData.priority) {
                            case "🔴": return colors ? colors.red : "#f38ba8";
                            case "🟡": return colors ? colors.peach : "#fab387";
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

                    Text {
                        text: modelData.description || ""
                        color: colors ? colors.subtext0 : "#a6adc8"
                        font.pixelSize: cfg.fontBase
                        wrapMode: Text.Wrap
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
                border.width: itemDel.highlighted ? 2 : 0
                border.color: Qt.rgba(colors.blue.r, colors.blue.g, colors.blue.b, 0.8)
            }

            onClicked: {
                detailPopup.type = "todo";
                detailPopup.itemData = modelData;
                detailPopup.open();
            }
        }
    }

    DetailPopup { id: detailPopup }
}
