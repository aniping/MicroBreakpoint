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
    property int selectedSearchIndex: -1

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
        selectedSearchIndex = -1
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
            selectedSearchIndex = -1
            return
        }
        var data = JSON.parse(bridge.searchPayload(callId, payloadType, searchText))
        searchMatches = data.matches || []
        selectedSearchIndex = searchMatches.length > 0 ? 0 : -1
    }

    function clearSearch() {
        searchText = ""
        searchMatches = []
        selectedSearchIndex = -1
    }

    function searchSummary() {
        if (!searchText) return "输入关键词后搜索完整 payload"
        if (searchMatches.length === 0) return "没有匹配结果"
        return "找到 " + searchMatches.length + " 处匹配"
    }

    function compactPreview(value) {
        return String(value || "").replace(/\s+/g, " ")
    }

    component PayloadActionButton: Button {
        id: actionButton
        property string variant: "neutral"
        implicitHeight: 30
        padding: 0
        background: Rectangle {
            radius: 4
            color: !actionButton.enabled ? "transparent"
                  : actionButton.variant === "primary" ? (actionButton.hovered ? viewer.appTheme.primaryHover : viewer.appTheme.primary)
                  : actionButton.hovered ? viewer.appTheme.panelHover : viewer.appTheme.panelBgAlt
            border.color: actionButton.variant === "primary" ? viewer.appTheme.primary : viewer.appTheme.border
        }
        contentItem: Text {
            text: actionButton.text
            color: !actionButton.enabled ? viewer.appTheme.textDisabled
                  : actionButton.variant === "primary" ? viewer.appTheme.onAccent : viewer.appTheme.textNormal
            font.pixelSize: 12
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    component SearchField: TextField {
        id: field
        implicitHeight: 34
        leftPadding: 30
        rightPadding: 8
        selectByMouse: true
        color: viewer.appTheme.textNormal
        placeholderTextColor: viewer.appTheme.textDisabled
        font.pixelSize: 12
        background: Rectangle {
            radius: 5
            color: viewer.appTheme.inputBg
            border.color: field.activeFocus ? viewer.appTheme.primary : viewer.appTheme.border
        }
        Text {
            text: "⌕"
            color: viewer.appTheme.textMuted
            font.pixelSize: 16
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
        }
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
            PayloadActionButton { text: "加载更多"; variant: viewer.hasMore ? "primary" : "neutral"; enabled: viewer.hasMore; Layout.preferredWidth: 82; onClicked: viewer.loadMore() }
            PayloadActionButton { text: "导出完整"; enabled: !!viewer.callId; Layout.preferredWidth: 82; onClicked: bridge.exportPayload(viewer.callId, viewer.payloadType) }
            PayloadActionButton { text: "复制预览"; enabled: viewer.displayText.length > 0; Layout.preferredWidth: 82; onClicked: bridge.copyText(viewer.displayText) }
            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: searchPanel.implicitHeight + 18
            radius: 6
            color: viewer.appTheme.panelBgAlt
            border.color: viewer.appTheme.borderSoft

            ColumnLayout {
                id: searchPanel
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 9
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    SearchField {
                        Layout.fillWidth: true
                        text: viewer.searchText
                        placeholderText: "搜索完整 payload"
                        onTextChanged: viewer.searchText = text
                        onAccepted: viewer.runSearch()
                    }

                    PayloadActionButton {
                        text: "搜索"
                        variant: "primary"
                        enabled: viewer.searchText.length > 0
                        Layout.preferredWidth: 64
                        onClicked: viewer.runSearch()
                    }

                    PayloadActionButton {
                        text: "清空"
                        enabled: viewer.searchText.length > 0 || viewer.searchMatches.length > 0
                        Layout.preferredWidth: 56
                        onClicked: viewer.clearSearch()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: viewer.searchSummary()
                        color: viewer.searchMatches.length > 0 ? viewer.appTheme.primary : viewer.appTheme.textMuted
                        font.pixelSize: 11
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: viewer.searchMatches.length > 0
                        text: "结果来自后端"
                        color: viewer.appTheme.textDisabled
                        font.pixelSize: 11
                    }
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: viewer.searchMatches.length > 0 ? Math.min(148, viewer.searchMatches.length * 48 + 6) : 0
            visible: viewer.searchMatches.length > 0
            clip: true
            model: viewer.searchMatches
            spacing: 6
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 42
                radius: 5
                color: viewer.selectedSearchIndex === index ? viewer.appTheme.panelActive : viewer.appTheme.panelBgAlt
                border.color: viewer.selectedSearchIndex === index ? viewer.appTheme.primary : viewer.appTheme.borderSoft

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Rectangle {
                        Layout.preferredWidth: 54
                        Layout.preferredHeight: 24
                        radius: 4
                        color: viewer.appTheme.primarySoft
                        border.color: viewer.appTheme.primary
                        Text {
                            anchors.centerIn: parent
                            text: "@" + modelData.offset
                            color: viewer.appTheme.primary
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        text: viewer.compactPreview(modelData.preview)
                        color: viewer.appTheme.textNormal
                        font.pixelSize: 12
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: viewer.selectedSearchIndex = index
                }
            }
        }
    }
}
