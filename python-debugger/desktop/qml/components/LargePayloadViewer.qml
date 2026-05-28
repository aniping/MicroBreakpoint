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

        TextArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: viewer.currentText
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            color: viewer.appTheme.textNormal
            font.family: "Consolas"
            font.pixelSize: 12
            background: Rectangle {
                color: viewer.appTheme.inputBg
                border.color: viewer.appTheme.border
                radius: 4
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Button { text: "加载更多"; enabled: viewer.hasMore; onClicked: viewer.loadMore() }
            Button { text: "导出完整"; enabled: !!viewer.callId; onClicked: bridge.exportPayload(viewer.callId, viewer.payloadType) }
            Button { text: "复制当前预览"; enabled: viewer.currentText.length > 0; onClicked: bridge.copyText(viewer.currentText) }
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
