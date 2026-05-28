import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: viewer

    property var appTheme
    property string callId: ""
    property string payloadType: "params"
    property string title: "payload"
    property string preview: ""
    property int payloadSize: 0
    property string payloadHash: ""
    property bool truncated: false
    property int nextOffset: 0
    property bool hasMore: false
    property string currentText: preview || ""
    property string displayText: formatJsonPreview(currentText)
    property string searchText: ""
    property var searchMatches: []

    function sizeText(bytes) {
        var value = Number(bytes || 0)
        if (value >= 1024 * 1024) return (value / 1024 / 1024).toFixed(1) + " MB"
        if (value >= 1024) return (value / 1024).toFixed(1) + " KB"
        return value + " B"
    }

    function resetContent() {
        currentText = preview || ""
        nextOffset = truncated ? Math.min(payloadSize, 8192) : payloadSize
        hasMore = !!truncated
        searchMatches = []
    }

    function formatJsonPreview(text) {
        var value = String(text || "")
        if (value.length === 0 || value.length > 262144) return value
        var trimmed = value.trim()
        if (!(trimmed.charAt(0) === "{" || trimmed.charAt(0) === "[")) return value
        try {
            return JSON.stringify(JSON.parse(trimmed), null, 2)
        } catch (e) {
            return value
        }
    }

    function lineNumbers(text) {
        var lines = Math.max(1, String(text || "").split("\n").length)
        var result = []
        for (var i = 1; i <= lines; i++) result.push(String(i))
        return result.join("\n")
    }

    function loadMore() {
        if (!callId || !hasMore) return
        var data = JSON.parse(bridge.loadPayloadChunk(callId, payloadType, nextOffset, 8192))
        if (data.success === false) return
        if ((currentText.length + String(data.content || "").length) > 262144) currentText = String(data.content || "")
        else currentText += String(data.content || "")
        nextOffset = Number(data.nextOffset || nextOffset)
        hasMore = !!data.hasMore
    }

    function runSearch() {
        if (!callId || !searchText) {
            searchMatches = []
            return
        }
        var data = JSON.parse(bridge.searchPayload(callId, payloadType, searchText))
        searchMatches = data.matches || []
    }

    onCallIdChanged: resetContent()
    onPayloadTypeChanged: resetContent()
    onPreviewChanged: resetContent()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: viewer.title
                color: viewer.appTheme.textStrong
                font.pixelSize: 14
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                text: viewer.sizeText(viewer.payloadSize)
                color: viewer.appTheme.textMuted
                font.pixelSize: 12
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Hash: " + (viewer.payloadHash || "-")
            color: viewer.appTheme.textMuted
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Text {
            visible: viewer.truncated
            Layout.fillWidth: true
            text: "内容较大，仅展示前 8KB，可加载更多或导出完整内容。"
            color: viewer.appTheme.warning
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: viewer.appTheme.inputBg
            border.color: viewer.appTheme.border
            radius: 4
            clip: true

            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.preferredWidth: 44
                    Layout.fillHeight: true
                    color: viewer.appTheme.panelBgAlt
                    border.color: viewer.appTheme.border
                    Text {
                        anchors.fill: parent
                        anchors.topMargin: 8
                        anchors.leftMargin: 6
                        anchors.rightMargin: 8
                        text: viewer.lineNumbers(viewer.displayText)
                        color: viewer.appTheme.textDisabled
                        font.family: "Consolas"
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignRight
                        lineHeightMode: Text.FixedHeight
                        lineHeight: 17
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.AllButtons
                        cursorShape: Qt.ArrowCursor
                        onPressed: function(mouse) { mouse.accepted = true }
                        onPositionChanged: function(mouse) { mouse.accepted = true }
                    }
                }

                TextArea {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: viewer.displayText
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.NoWrap
                    color: viewer.appTheme.textNormal
                    font.family: "Consolas"
                    font.pixelSize: 12
                    leftPadding: 10
                    topPadding: 8
                    background: Rectangle { color: "transparent" }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Button { text: "加载更多"; enabled: viewer.hasMore; onClicked: viewer.loadMore() }
            Button { text: "导出完整"; enabled: !!viewer.callId; onClicked: bridge.exportPayload(viewer.callId, viewer.payloadType) }
            Button { text: "复制当前预览"; enabled: viewer.displayText.length > 0; onClicked: bridge.copyText(viewer.displayText) }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextField {
                Layout.fillWidth: true
                text: viewer.searchText
                placeholderText: "后端搜索"
                onTextChanged: viewer.searchText = text
            }
            Button { text: "搜索"; enabled: viewer.searchText.length > 0; onClicked: viewer.runSearch() }
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: viewer.searchMatches.length > 0 ? 88 : 0
            visible: viewer.searchMatches.length > 0
            clip: true
            model: viewer.searchMatches
            delegate: Text {
                required property var modelData
                width: ListView.view.width
                text: "@" + modelData.offset + "  " + modelData.preview
                color: viewer.appTheme.textMuted
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }
}
