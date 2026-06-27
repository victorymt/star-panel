import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Popup {
    id: root

    property string type: "todo"
    property var itemData: ({})

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    dim: true

    implicitWidth: Math.min(parent ? parent.width * 0.9 : 380, 380)
    implicitHeight: Math.min(contentColumn.implicitHeight + padding * 2, parent ? parent.height * 0.7 : 400)
    padding: 16

    x: (parent.width - width) / 2
    y: (parent.height - height) / 2

    background: Rectangle {
        radius: 12
        color: Qt.rgba(theme.base.r, theme.base.g, theme.base.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(theme.surface1.r, theme.surface1.g, theme.surface1.b, 0.4)
    }

    contentItem: ColumnLayout {
        id: contentColumn
        spacing: 10

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
                    if (!itemData.id) return;
                    Quickshell.execDetached(["starcatch", "todo", actionBtn.actions.cmd, itemData.id]);
                    root.close();
                    Qt.callLater(function() { panel.reloadData("todo"); });
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
                    Quickshell.execDetached(["starcatch", "todo", "archive", itemData.id]);
                    root.close();
                    Qt.callLater(function() { panel.reloadData("todo"); });
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

        // ── Close button for non-todo ──
        Button {
            Layout.fillWidth: true
            visible: type !== "todo"
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
