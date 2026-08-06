import QtQuick

Text {
    id: root

    property string markdown: ""

    text: markdown
    textFormat: Text.MarkdownText
    wrapMode: Text.WordWrap
}
