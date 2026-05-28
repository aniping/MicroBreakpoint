import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: viewer

    property var appTheme
    property string callId: ""
    property string payloadId: ""
    property string payloadType: "params"
    property string title: "payload"
    property string preview: ""
    property int payloadSize: 0
    property string payloadHash: ""
    property bool truncated: false
    property int nextOffset: 0
    property bool hasMore: false
    property bool loadedFromChunks: false
    property bool loadingAll: false
    property bool loadedAll: false
    property string currentText: preview || ""
    property string displayText: formatJsonPreview(currentText)
    property string searchText: ""
    property var searchMatches: []
    property int selectedSearchIndex: -1
    property string searchError: ""
    property string loadError: ""

    function hasPayloadSource() {
        return (payloadId && payloadId.length > 0) || (callId && callId.length > 0)
    }

    function sizeText(bytes) {
        var value = Number(bytes || 0)
        if (value >= 1024 * 1024) return (value / 1024 / 1024).toFixed(1) + " MB"
        if (value >= 1024) return (value / 1024).toFixed(1) + " KB"
        return value + " B"
    }

    function utf8Size(text) {
        return unescape(encodeURIComponent(String(text || ""))).length
    }

    function previewIsComplete() {
        if (truncated) return false
        var size = Number(payloadSize || 0)
        if (size <= 0) return String(preview || "").length > 0
        return utf8Size(preview) >= size
    }

    function resetContent() {
        currentText = preview || ""
        nextOffset = 0
        loadedFromChunks = false
        loadingAll = false
        loadedAll = previewIsComplete()
        hasMore = hasPayloadSource() && !loadedAll
        loadError = ""
        searchError = ""
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

    function loadChunk(offset, limit) {
        if (payloadId && payloadId.length > 0) {
            return JSON.parse(bridge.loadPayloadChunkById(payloadId, offset, limit))
        }
        return JSON.parse(bridge.loadPayloadChunk(callId, payloadType, offset, limit))
    }

    function requestLoadAll() {
        if (payloadSize > 10 * 1024 * 1024 && !loadedAll) {
            largeLoadConfirm.open()
            return
        }
        loadAll()
    }

    function loadAll() {
        if (!hasPayloadSource() || loadingAll) return

        loadingAll = true
        loadError = ""
        var offset = 0
        var chunks = []
        var limit = 1048576

        while (true) {
            var data = loadChunk(offset, limit)
            if (!data || data.success === false) {
                loadError = data && (data.message || data.error) ? String(data.message || data.error) : "payload load failed"
                break
            }

            chunks.push(String(data.content || ""))

            if (!data.hasMore) {
                currentText = chunks.join("")
                nextOffset = Number(data.nextOffset || 0)
                hasMore = false
                loadedFromChunks = true
                loadedAll = true
                break
            }

            var next = Number(data.nextOffset || 0)
            if (next <= offset) {
                loadError = "payload chunk offset did not advance"
                break
            }
            offset = next
        }

        loadingAll = false
    }

    function runSearch() {
        if (!searchText || !hasPayloadSource()) {
            searchMatches = []
            selectedSearchIndex = -1
            searchError = ""
            return
        }
        try {
            var data = payloadId && payloadId.length > 0
                    ? JSON.parse(bridge.searchPayloadById(payloadId, searchText))
                    : JSON.parse(bridge.searchPayload(callId, payloadType, searchText))
            if (!data || data.success === false) {
                searchError = data && (data.message || data.error) ? String(data.message || data.error) : "payload search failed"
                searchMatches = []
                selectedSearchIndex = -1
                return
            }
            searchError = ""
            searchMatches = data.matches || []
            selectedSearchIndex = searchMatches.length > 0 ? 0 : -1
        } catch (e) {
            searchError = String(e)
            searchMatches = []
            selectedSearchIndex = -1
        }
    }

    function clearSearch() {
        searchText = ""
        searchMatches = []
        selectedSearchIndex = -1
        searchError = ""
    }

    function searchSummary() {
        if (searchError.length > 0) return searchError
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
        implicitHeight: 30
        leftPadding: 30
        rightPadding: 8
        topPadding: 0
        bottomPadding: 0
        verticalAlignment: TextInput.AlignVCenter
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
    onPayloadIdChanged: resetContent()
    onPayloadTypeChanged: resetContent()
    onPreviewChanged: resetContent()
    onPayloadSizeChanged: resetContent()
    onTruncatedChanged: resetContent()

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
            text: "内容较大，当前仅展示预览。可加载全部到查看器，或直接导出完整文件。"
            color: viewer.appTheme.warning
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            PayloadActionButton {
                text: viewer.loadingAll ? "加载中..." : (viewer.loadedAll ? "已加载全部" : "加载全部")
                variant: viewer.loadedAll ? "neutral" : "primary"
                enabled: viewer.hasPayloadSource() && !viewer.loadingAll && !viewer.loadedAll
                Layout.preferredWidth: 88
                onClicked: viewer.requestLoadAll()
            }
            PayloadActionButton {
                text: "导出完整"
                enabled: viewer.hasPayloadSource()
                Layout.preferredWidth: 82
                onClicked: viewer.payloadId && viewer.payloadId.length > 0 ? bridge.exportPayloadById(viewer.payloadId) : bridge.exportPayload(viewer.callId, viewer.payloadType)
            }
            PayloadActionButton {
                text: "复制预览"
                enabled: viewer.displayText.length > 0
                Layout.preferredWidth: 82
                onClicked: bridge.copyText(viewer.displayText)
            }
            Item { Layout.fillWidth: true }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            SearchField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: 32
                text: viewer.searchText
                placeholderText: "搜索完整 payload"
                onTextChanged: viewer.searchText = text
                onAccepted: viewer.runSearch()
            }
            PayloadActionButton {
                text: "搜索"
                variant: "primary"
                enabled: viewer.searchText.length > 0 && viewer.hasPayloadSource()
                Layout.preferredWidth: 74
                Layout.preferredHeight: 32
                onClicked: {
                    searchField.forceActiveFocus()
                    viewer.runSearch()
                }
            }
            PayloadActionButton {
                text: "清空"
                enabled: viewer.searchText.length > 0 || viewer.searchMatches.length > 0
                Layout.preferredWidth: 60
                Layout.preferredHeight: 32
                onClicked: viewer.clearSearch()
            }
        }

        Text {
            Layout.fillWidth: true
            visible: viewer.loadError.length > 0 || viewer.searchText.length > 0 || viewer.searchError.length > 0
            text: viewer.loadError.length > 0 ? viewer.loadError : viewer.searchSummary()
            color: (viewer.loadError.length > 0 || viewer.searchError.length > 0) ? viewer.appTheme.danger : (viewer.searchMatches.length > 0 ? viewer.appTheme.primary : viewer.appTheme.textMuted)
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(118, viewer.searchMatches.length * 42 + 14)
            visible: viewer.searchMatches.length > 0
            radius: 5
            color: viewer.appTheme.panelBgAlt
            border.color: viewer.appTheme.border
            clip: true

            ListView {
                anchors.fill: parent
                anchors.margins: 7
                clip: true
                model: viewer.searchMatches
                spacing: 6
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 36
                    radius: 4
                    color: viewer.selectedSearchIndex === index ? viewer.appTheme.panelActive : viewer.appTheme.panelBg
                    border.color: viewer.selectedSearchIndex === index ? viewer.appTheme.primary : viewer.appTheme.borderSoft

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 54
                            Layout.preferredHeight: 22
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

        Rectangle {
            id: payloadFrame
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: viewer.appTheme.inputBg
            border.color: viewer.appTheme.border
            radius: 4
            clip: true

            Flickable {
                id: payloadFlick
                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentWidth: Math.max(width, lineNumberColumn.width + codeText.implicitWidth + 28)
                contentHeight: Math.max(height, codeText.implicitHeight + 16)
                flickableDirection: Flickable.HorizontalAndVerticalFlick
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 8; radius: 4; color: parent.pressed ? viewer.appTheme.primary : viewer.appTheme.textDisabled }
                    background: Rectangle { color: "transparent" }
                }
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitHeight: 8; radius: 4; color: parent.pressed ? viewer.appTheme.primary : viewer.appTheme.textDisabled }
                    background: Rectangle { color: "transparent" }
                }

                Row {
                    width: payloadFlick.contentWidth
                    height: payloadFlick.contentHeight
                    spacing: 0

                    Rectangle {
                        id: lineNumberColumn
                        width: 44
                        height: parent.height
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
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.AllButtons
                            cursorShape: Qt.ArrowCursor
                            onPressed: function(mouse) { mouse.accepted = true }
                            onPositionChanged: function(mouse) { mouse.accepted = true }
                        }
                    }

                    Item {
                        width: Math.max(payloadFlick.width - lineNumberColumn.width, codeText.implicitWidth + 20)
                        height: parent.height
                        TextEdit {
                            id: codeText
                            x: 10
                            y: 8
                            text: viewer.displayText
                            readOnly: true
                            selectByMouse: true
                            color: viewer.appTheme.textNormal
                            font.family: "Consolas"
                            font.pixelSize: 12
                            wrapMode: TextEdit.NoWrap
                        }
                    }
                }
            }
        }
    }

    Popup {
        id: largeLoadConfirm
        parent: Overlay.overlay
        width: Math.min(viewer.width - 24, 420)
        height: confirmColumn.implicitHeight + 28
        x: viewer.mapToItem(Overlay.overlay, (viewer.width - width) / 2, 0).x
        y: viewer.mapToItem(Overlay.overlay, 0, Math.max(24, viewer.height / 2 - height / 2)).y
        modal: true
        closePolicy: Popup.CloseOnEscape
        padding: 14
        background: Rectangle {
            color: viewer.appTheme.panelBg
            border.color: viewer.appTheme.border
            radius: 6
        }
        contentItem: ColumnLayout {
            id: confirmColumn
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: "完整内容较大，加载到界面可能变慢，建议导出查看。是否继续加载全部？"
                color: viewer.appTheme.textNormal
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                PayloadActionButton {
                    text: "取消"
                    Layout.preferredWidth: 72
                    onClicked: largeLoadConfirm.close()
                }
                PayloadActionButton {
                    text: "继续"
                    variant: "primary"
                    Layout.preferredWidth: 72
                    onClicked: {
                        largeLoadConfirm.close()
                        viewer.loadAll()
                    }
                }
            }
        }
    }
}
