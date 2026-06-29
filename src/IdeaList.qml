import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

/// IdeaList — 灵感列表组件
Item {
    id: root

    property var items: []
    property bool loading: false
    readonly property var colors: theme
    property string searchText: ""
    property bool searchActive: searchField.activeFocus
    readonly property string itemType: "idea"

    // vim gg/dd/gt 状态机
    property bool _pendingG: false
    property bool _pendingD: false

    // 当前高亮项 id —— 用于 model 替换后还原高亮位置
    property string currentItemId: ""
    // 导航时快照的 index —— Qt 在 JS 数组 model 替换时重置 currentIndex，
    // 故 onModelChanged 的 fallback 必须用此快照而非当时的 currentIndex。
    property int lastIndex: 0

    function focusSearch() { searchField.forceActiveFocus(); }
    function focusList() { listView.forceActiveFocus(); }

    function _trackCurrent() {
        var m = listView.model;
        var i = listView.currentIndex;
        if (i >= 0 && i < m.length && m[i]) {
            root.currentItemId = m[i].id || "";
            root.lastIndex = i;
        }
    }

    // gg 第二次 g 的超时（500ms 内按第二次 g 才算 gg）
    Timer { id: gReset; interval: 500; onTriggered: root._pendingG = false }
    // dd 第二次 d 的超时（1.5s 内按第二次 d 才算 dd）
    Timer { id: dReset; interval: 1500; onTriggered: root._pendingD = false }

    // 过滤后的列表（搜索）—— 与 listView.model 同源，供空状态判断使用
    readonly property var filteredItems: {
        var all = items || [];
        if (!searchText.trim()) return all;
        var q = searchText.trim().toLowerCase();
        return all.filter(function(item) {
            return (item.title && item.title.toLowerCase().indexOf(q) >= 0)
                || (item.content && item.content.toLowerCase().indexOf(q) >= 0);
        });
    }

    // ── 搜索框 ──
    TextField {
        id: searchField
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 28
        placeholderText: "🔍 搜索灵感..."
        placeholderTextColor: colors ? colors.overlay0 : "#6c7086"
        color: colors ? colors.text : "#cdd6f4"
        font.pixelSize: cfg.fontSmall
        verticalAlignment: Text.AlignVCenter
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
                    searchField.cursorPosition = 0;
                    event.accepted = true;
                } else if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_E) {
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

    // ── 空状态 ──
    Rectangle {
        anchors.fill: parent
        visible: !loading && filteredItems.length === 0
        color: "transparent"

        Text {
            anchors.centerIn: parent
            text: {
                if (searchText.trim()) return "🔍 没有匹配的结果";
                return "💭 暂无灵感\n等待星光的降临~";
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
            mid: colors ? colors.mauve : "#cba6f7"
        }
    }

    // ── 灵感列表 ──
    ListView {
        id: listView
        anchors.top: searchField.bottom
        anchors.topMargin: 4
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        visible: !loading
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
            } else if (event.key === Qt.Key_J || event.key === Qt.Key_Down
                || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_N)) {
                if (currentIndex < model.length - 1) currentIndex++;
                positionViewAtIndex(currentIndex, ListView.Contain);
                root._trackCurrent();
                event.accepted = true;
            } else if (event.key === Qt.Key_K || event.key === Qt.Key_Up
                       || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_P)) {
                if (currentIndex > 0) currentIndex--;
                positionViewAtIndex(currentIndex, ListView.Contain);
                root._trackCurrent();
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
                    positionViewAtIndex(currentIndex, ListView.END);
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
            } else if (event.key === Qt.Key_D && !event.modifiers) {
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
                    detailPopup.type = "idea";
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
            implicitHeight: Math.max(52, contentColumn.implicitHeight + 16)
            highlighted: ListView.isCurrentItem

            contentItem: ColumnLayout {
                id: contentColumn
                spacing: 2

                // vim 风格当前行指示符 ▸
                Text {
                    text: "▸"
                    color: colors ? colors.blue : "#89b4fa"
                    font.pixelSize: cfg.fontSmall
                    font.bold: true
                    visible: itemDel.highlighted
                    Layout.leftMargin: 0
                }

                Text {
                    text: modelData.title || "(untitled)"
                    color: colors ? colors.text : "#cdd6f4"
                    font.pixelSize: cfg.fontBase
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: modelData.content || ""
                    color: colors ? colors.subtext0 : "#a6adc8"
                    font.pixelSize: cfg.fontSmall
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    maximumLineCount: 1
                }

                // 标签
                TagList {
                    tags: modelData.tags
                    tagColor: colors ? colors.sapphire : "#74c7ec"
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
                listView.currentIndex = index;
                root._trackCurrent();
                detailPopup.type = "idea";
                detailPopup.itemData = modelData;
                detailPopup.open();
            }
        }
    }

    DetailPopup { id: detailPopup }
}
