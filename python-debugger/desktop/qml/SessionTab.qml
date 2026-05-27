import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page
    property var appTheme
    property var items: []
    property string activeSessionId: ""
    property bool canClearSessions: false
    property bool debugging: false
    property int pausedCount: 0
    property string exportSessionId: ""
    property string exportArchiveName: ""
    property string exportRemark: ""
    property bool importLockInterfaces: false
    property string duplicateExistingSessionId: ""
    property string duplicateArchiveName: ""
    property string duplicateImportFileName: ""

    function modeText(mode) {
        if (mode === "record") return "记录"
        if (mode === "debug") return "调试"
        return "空闲"
    }

    function modeType(mode) {
        if (mode === "record") return "primary"
        if (mode === "debug") return "success"
        return "neutral"
    }

    function compactTime(value) {
        if (!value) return "-"
        return String(value).replace("T", " ").split("+")[0]
    }

    function stripMbrecSuffix(name) {
        var text = String(name || "")
        return text.toLowerCase().endsWith(".mbrec") ? text.slice(0, -6) : text
    }

    function sessionDisplayName(item) {
        if (!item) return "未命名"
        if (item.display_name || item.displayName) return item.display_name || item.displayName
        if (item.import_file_name || item.importFileName) return stripMbrecSuffix(item.import_file_name || item.importFileName)
        if (item.archive_name || item.archiveName) return item.archive_name || item.archiveName
        return "未命名"
    }

    function isImportedSession(item) {
        return !!(item && (item.import_file_name || item.importFileName || item.imported_at || item.importedAt))
    }

    function sessionSubtitle(item) {
        if (!item) return "-"
        var parts = ["服务: " + (item.service_name || item.serviceName || "-")]
        if (item.archive_name || item.archiveName) parts.push("归档: " + (item.archive_name || item.archiveName))
        if (item.archive_remark || item.archiveRemark || item.remark) parts.push("备注: " + (item.archive_remark || item.archiveRemark || item.remark))
        return parts.join("    ")
    }

    function currentHint() {
        return activeSessionId ? "当前会话: " + activeSessionId : "请先新建会话，再开始调试"
    }

    function confirmClearSessions() {
        confirmDialog.ask("清空历史会话", "将删除全部历史会话，以及对应的调用记录、接口和断点。此操作不可撤销。", "清空历史", function() {
            bridge.clearSessions()
        })
    }

    function confirmDeleteSession(sessionId) {
        confirmDialog.ask("删除会话", "将删除会话 " + sessionId + " 以及它的调用记录、接口和断点。此操作不可撤销。", "删除", function() {
            bridge.deleteSession(sessionId)
        })
    }

    function openExportDialog(item) {
        exportSessionId = item.id || ""
        exportArchiveName = item.archive_name || item.archiveName || page.sessionDisplayName(item) || item.id || "session"
        exportRemark = item.archive_remark || item.archiveRemark || item.remark || ""
        exportDialog.open()
    }

    function requestImport() {
        importDialog.close()
        if (debugging) {
            var message = pausedCount > 0
                    ? "当前正在调试，并存在暂停中的 Java 调用。导入 Session 会释放所有暂停调用、停止当前调试，并切换到导入的历史 Session。是否继续？"
                    : "当前正在调试。导入 Session 会停止当前调试，并切换到导入的历史 Session。是否继续？"
            confirmDialog.ask("导入 Session", message, "继续导入", function() {
                bridge.importSession(page.importLockInterfaces)
            })
            return
        }
        bridge.importSession(page.importLockInterfaces)
    }

    function duplicateMessage() {
        var text = "该 Session 已存在，不能重复导入。"
        if (duplicateImportFileName) text += "\n导入文件: " + stripMbrecSuffix(duplicateImportFileName)
        if (duplicateArchiveName) text += "\narchiveName: " + duplicateArchiveName
        text += "\nexistingSessionId: " + duplicateExistingSessionId
        return text
    }

    ConfirmDialog {
        id: confirmDialog
        appTheme: page.appTheme
    }

    Connections {
        target: bridge
        function onImportDuplicate(payload) {
            var data = JSON.parse(payload)
            page.duplicateExistingSessionId = data.existingSessionId || ""
            page.duplicateArchiveName = data.archiveName || ""
            page.duplicateImportFileName = data.importFileName || ""
            duplicateImportDialog.open()
        }
    }

    Popup {
        id: duplicateImportDialog
        modal: true
        focus: true
        width: 440
        height: 238
        anchors.centerIn: parent
        background: Rectangle { radius: 6; color: page.appTheme.panelBg; border.color: page.appTheme.border }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            Text { text: "该 Session 已存在"; color: page.appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true; wrapMode: Text.Wrap }
            Text { text: page.duplicateMessage(); color: page.appTheme.textNormal; font.pixelSize: 13; lineHeight: 1.25; wrapMode: Text.Wrap; Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                MbButton { appTheme: page.appTheme; text: "取消"; variant: "neutral"; Layout.preferredWidth: 86; Layout.preferredHeight: 36; onClicked: duplicateImportDialog.close() }
                MbButton {
                    appTheme: page.appTheme
                    text: "打开已有 Session"
                    variant: "primary"
                    Layout.preferredWidth: 138
                    Layout.preferredHeight: 36
                    enabled: page.duplicateExistingSessionId.length > 0
                    onClicked: {
                        var sessionId = page.duplicateExistingSessionId
                        duplicateImportDialog.close()
                        bridge.openExistingSession(sessionId)
                    }
                }
            }
        }
    }

    Popup {
        id: exportDialog
        modal: true
        focus: true
        width: 420
        height: 230
        anchors.centerIn: parent
        background: Rectangle { radius: 6; color: page.appTheme.panelBg; border.color: page.appTheme.border }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            Text { text: "导出 .mbrec"; color: page.appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
            MbTextField { appTheme: page.appTheme; text: page.exportArchiveName; placeholderText: "归档名称"; Layout.fillWidth: true; onTextChanged: page.exportArchiveName = text }
            MbTextField { appTheme: page.appTheme; text: page.exportRemark; placeholderText: "备注"; Layout.fillWidth: true; onTextChanged: page.exportRemark = text }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                MbButton { appTheme: page.appTheme; text: "取消"; variant: "neutral"; Layout.preferredWidth: 86; Layout.preferredHeight: 36; onClicked: exportDialog.close() }
                MbButton {
                    appTheme: page.appTheme
                    text: "导出"
                    variant: "primary"
                    Layout.preferredWidth: 86
                    Layout.preferredHeight: 36
                    enabled: page.exportSessionId.length > 0
                    onClicked: {
                        bridge.exportSession(page.exportSessionId, page.exportArchiveName, page.exportRemark)
                        exportDialog.close()
                    }
                }
            }
        }
    }

    Popup {
        id: importDialog
        modal: true
        focus: true
        width: 380
        height: 178
        anchors.centerIn: parent
        background: Rectangle { radius: 6; color: page.appTheme.panelBg; border.color: page.appTheme.border }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            Text { text: "导入 .mbrec"; color: page.appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text { text: "导入后锁定接口"; color: page.appTheme.textNormal; font.pixelSize: 13; Layout.fillWidth: true }
                MbSwitch { appTheme: page.appTheme; checked: page.importLockInterfaces; onToggled: function(value) { page.importLockInterfaces = value } }
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                MbButton { appTheme: page.appTheme; text: "取消"; variant: "neutral"; Layout.preferredWidth: 86; Layout.preferredHeight: 36; onClicked: importDialog.close() }
                MbButton {
                    appTheme: page.appTheme
                    text: "选择文件"
                    variant: "primary"
                    Layout.preferredWidth: 104
                    Layout.preferredHeight: 36
                    onClicked: page.requestImport()
                }
            }
        }
    }

    MbPanel {
        appTheme: page.appTheme
        padding: 0
        anchors.fill: parent
        anchors.margins: 12

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: appTheme.panelBg
                border.color: appTheme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "历史会话"
                            color: appTheme.textStrong
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: page.currentHint()
                            color: activeSessionId ? appTheme.textMuted : appTheme.warning
                            font.pixelSize: 13
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                    }

                    MbButton {
                        appTheme: page.appTheme
                        text: "新建会话"
                        iconText: "+"
                        variant: "primary"
                        Layout.preferredWidth: 118
                        Layout.preferredHeight: 38
                        onClicked: bridge.createSession()
                    }

                    MbButton {
                        appTheme: page.appTheme
                        text: "导入 .mbrec"
                        iconText: "↓"
                        variant: "neutral"
                        Layout.preferredWidth: 124
                        Layout.preferredHeight: 38
                        onClicked: importDialog.open()
                    }

                    MbButton {
                        appTheme: page.appTheme
                        text: "清空历史"
                        iconText: "×"
                        variant: "danger"
                        enabled: page.canClearSessions && items.length > 0
                        Layout.preferredWidth: 118
                        Layout.preferredHeight: 38
                        onClicked: page.confirmClearSessions()
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    anchors.fill: parent
                    model: items
                    clip: true
                    spacing: 0

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: list.width
                        height: 168
                        color: modelData.id === activeSessionId ? appTheme.panelActive : (index % 2 ? appTheme.panelBgAlt : appTheme.panelBg)
                        border.color: appTheme.borderSoft

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 4
                                Layout.preferredHeight: 84
                                radius: 2
                                color: modelData.id === activeSessionId ? appTheme.success : appTheme.textMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    MbTag {
                                        appTheme: page.appTheme
                                        text: page.modeText(modelData.mode)
                                        type: page.modeType(modelData.mode)
                                    }

                                    MbTag {
                                        appTheme: page.appTheme
                                        text: page.isImportedSession(modelData) ? "导入" : "本地"
                                        type: page.isImportedSession(modelData) ? "primary" : "neutral"
                                    }

                                    Text {
                                        text: page.sessionDisplayName(modelData)
                                        color: appTheme.textStrong
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                    }

                                    MbTag {
                                        visible: modelData.id === activeSessionId
                                        appTheme: page.appTheme
                                        text: "当前会话"
                                        type: "success"
                                    }
                                }

                                Text {
                                    text: page.sessionSubtitle(modelData)
                                    color: appTheme.textMuted
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "SessionId: " + (modelData.id || "-")
                                    color: appTheme.textDisabled
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    elide: Text.ElideMiddle
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    MbStatusChip { appTheme: page.appTheme; label: "开始"; value: page.compactTime(modelData.start_time || modelData.created_at); type: "neutral"; Layout.preferredWidth: 210 }
                                    MbStatusChip { appTheme: page.appTheme; label: "结束"; value: page.compactTime(modelData.end_time); type: modelData.end_time ? "neutral" : "warning"; Layout.preferredWidth: 210 }
                                    MbStatusChip { appTheme: page.appTheme; label: "调用"; value: String(modelData.call_count || 0); type: "primary"; Layout.preferredWidth: 96 }
                                    MbStatusChip { appTheme: page.appTheme; label: "接口"; value: String(modelData.interface_count || 0); type: "neutral"; Layout.preferredWidth: 96 }
                                    MbStatusChip { appTheme: page.appTheme; label: "异常"; value: String(modelData.exception_count || 0); type: (modelData.exception_count || 0) > 0 ? "danger" : "neutral"; Layout.preferredWidth: 96 }
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 116
                                spacing: 8

                                MbButton {
                                    appTheme: page.appTheme
                                    text: modelData.id === activeSessionId ? "当前" : "打开会话"
                                    variant: "primary"
                                    enabled: modelData.id !== activeSessionId
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    onClicked: bridge.selectSession(modelData.id)
                                }

                                MbButton {
                                    appTheme: page.appTheme
                                    text: "导出 .mbrec"
                                    variant: "neutral"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    onClicked: page.openExportDialog(modelData)
                                }

                                MbButton {
                                    appTheme: page.appTheme
                                    text: "删除会话"
                                    variant: "danger"
                                    enabled: page.canClearSessions
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    onClicked: page.confirmDeleteSession(modelData.id)
                                }
                            }
                        }
                    }
                }

                Column {
                    visible: items.length === 0
                    anchors.centerIn: parent
                    spacing: 8

                    Text {
                        text: "暂无历史会话"
                        color: appTheme.textStrong
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "点击“新建会话”后开始调试"
                        color: appTheme.textMuted
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
