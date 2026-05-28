import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "theme"

ApplicationWindow {
    id: root
    visible: true
    width: 1620
    height: 980
    minimumWidth: 1100
    minimumHeight: 760
    title: "组件化断点调试工具"
    color: theme.windowBg

    property string themeMode: "dark"
    property color bg: theme.windowBg
    property color panel: theme.panelBg
    property color panel2: theme.panelBgAlt
    property color border: theme.border
    property color textStrong: theme.textStrong
    property color textNormal: theme.textNormal
    property color textMuted: theme.textMuted
    property color blue: theme.primary
    property color green: theme.success
    property color red: theme.danger
    property color amber: theme.warning

    property int currentPage: 0
    property var stateData: ({state: "NO_SESSION", mode: "idle", debugging: false, callCount: 0, discoveredInterfaceCount: 0, breakpointCount: 0, pausedCount: 0, interfaceLocked: false})
    property var callItems: []
    property int callListPage: 1
    property int callListPageSize: 50
    property int callListTotal: 0
    property var interfaceItems: []
    property var breakpointItems: []
    property var sessionItems: []
    property string resultText: ""
    property string callBreakpointFilter: ""
    property string selectedCallId: ""
    property string selectedCallStatus: ""
    property bool logExpanded: false

    function selectedCallIsPaused() {
        return selectedCallId.length > 0 && selectedCallStatus === "paused"
    }

    function logSummary() {
        if (!resultText || resultText.length === 0) return "暂无操作日志"
        var compact = resultText.replace(/\s+/g, " ")
        return compact.length > 180 ? compact.substring(0, 180) + "..." : compact
    }

    function confirmClearCurrentSession() {
        confirmDialog.ask("清空当前会话", "确认清空当前会话的数据吗？该操作会删除当前会话的接口、调用记录和相关断点。", "清空", function() {
            bridge.clearCalls()
        })
    }

    AppTheme {
        id: theme
        mode: root.themeMode
    }

    function modeText(mode) {
        if (stateData.state === "DEBUGGING_PAUSED") return "已暂停"
        if (mode === "debug") return "调试中"
        if (stateData.state === "NO_SESSION") return "无会话"
        return "空闲"
    }

    function modeColor(mode) {
        if (mode === "debug") return root.green
        return root.textMuted
    }

    Component.onCompleted: {
        root.themeMode = bridge.getThemeMode()
        bridge.refreshAll()
    }

    Connections {
        target: bridge
        function onStateChanged(payload) { stateData = JSON.parse(payload) }
        function onCallsChanged(payload) {
            var data = JSON.parse(payload)
            callItems = data.items || []
            callListPage = Number(data.page || 1)
            callListPageSize = Number(data.pageSize || 50)
            callListTotal = Number(data.total || callItems.length)
        }
        function onInterfacesChanged(payload) { interfaceItems = JSON.parse(payload).items || [] }
        function onBreakpointsChanged(payload) { breakpointItems = JSON.parse(payload).items || [] }
        function onSessionsChanged(payload) { sessionItems = JSON.parse(payload).items || [] }
        function onResultChanged(payload) { resultText = payload }
        function onThemeChanged(mode) { root.themeMode = mode }
        function onUserNotice(message) {
            noticeDialog.message = message
            noticeDialog.open()
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 1500
        onTriggered: bridge.refreshAll()
    }

    ConfirmDialog {
        id: confirmDialog
        appTheme: theme
    }

    Popup {
        id: noticeDialog
        property string message: ""
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape
        width: Math.min(420, parent ? parent.width - 32 : 420)
        x: parent ? Math.round((parent.width - width) / 2) : 0
        y: parent ? Math.round((parent.height - height) / 2) : 0
        background: Rectangle { radius: 6; color: theme.panelBg; border.color: theme.border }
        contentItem: ColumnLayout {
            spacing: 12
            Text { text: "提示"; color: theme.textStrong; font.pixelSize: 17; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
            Text { text: noticeDialog.message; color: theme.textNormal; font.pixelSize: 14; wrapMode: Text.Wrap; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                MbButton { appTheme: theme; text: "确定"; variant: "primary"; Layout.preferredWidth: 92; Layout.preferredHeight: 36; onClicked: noticeDialog.close() }
            }
        }
    }

    component ToolbarGroup: ColumnLayout {
        id: group
        property string title: ""
        default property alias content: buttonRow.data

        spacing: 4
        Layout.alignment: Qt.AlignVCenter

        Text {
            text: group.title
            color: theme.textMuted
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }

        RowLayout {
            id: buttonRow
            spacing: 8
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: theme.topBarBg
            border.color: theme.borderSoft
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12
                Rectangle {
                    width: 20
                    height: 20
                    radius: 5
                    gradient: Gradient {
                        GradientStop { position: 0; color: theme.primary }
                        GradientStop { position: 1; color: theme.primaryHover }
                    }
                    Text { anchors.centerIn: parent; text: "M"; color: theme.onAccent; font.bold: true; font.pixelSize: 13 }
                }
                Text {
                    text: root.title
                    color: root.textStrong
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                Button {
                    id: themeButton
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 32
                    text: root.themeMode === "dark" ? "☀" : "🌙"
                    onClicked: {
                        var nextMode = root.themeMode === "dark" ? "light" : "dark"
                        root.themeMode = nextMode
                        bridge.setThemeMode(nextMode)
                    }
                    ToolTip.visible: hovered
                    ToolTip.text: root.themeMode === "dark" ? "切换到亮色模式" : "切换到暗色模式"
                    background: Rectangle {
                        radius: 4
                        color: themeButton.pressed ? theme.panelActive : (themeButton.hovered ? theme.panelHover : theme.panelBgAlt)
                        border.color: theme.border
                    }
                    contentItem: Text {
                        text: themeButton.text
                        color: theme.textStrong
                        font.pixelSize: 17
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: theme.toolbarBg
            border.color: root.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 14
                ToolbarGroup {
                    title: "会话"
                    MbButton { appTheme: theme; text: "新建会话"; iconText: "+"; variant: "primary"; implicitWidth: 118; enabled: !stateData.debugging; onClicked: { bridge.createSession(); currentPage = 0 } }
                    MbButton { appTheme: theme; text: "清空当前"; iconText: "×"; variant: "danger"; implicitWidth: 118; enabled: !stateData.debugging && stateData.hasSession; onClicked: root.confirmClearCurrentSession() }
                }
                Rectangle { width: 1; Layout.preferredHeight: 36; color: root.border }
                ToolbarGroup {
                    title: "调试"
                    MbButton { appTheme: theme; text: "开始调试"; iconText: "▶"; variant: "primary"; implicitWidth: 118; enabled: !stateData.debugging; onClicked: bridge.startDebug() }
                    MbButton { appTheme: theme; text: "停止调试"; iconText: "■"; variant: "danger"; implicitWidth: 118; enabled: stateData.debugging; onClicked: bridge.stopDebug() }
                    MbButton { appTheme: theme; text: "重置状态"; iconText: "↺"; variant: "neutral"; implicitWidth: 118; enabled: stateData.debugging; onClicked: bridge.resetDebug() }
                }
                Rectangle { width: 1; Layout.preferredHeight: 36; color: root.border }
                ToolbarGroup {
                    title: "执行"
                    MbButton { appTheme: theme; text: "继续单个"; iconText: "▶"; variant: root.selectedCallIsPaused() ? "success" : "primary"; implicitWidth: 122; enabled: root.selectedCallIsPaused(); onClicked: bridge.continueCall(root.selectedCallId) }
                    MbButton { appTheme: theme; text: "继续全部"; iconText: "▶"; variant: stateData.pausedCount > 0 ? "success" : "primary"; implicitWidth: 118; enabled: stateData.pausedCount > 0; onClicked: bridge.continueAll() }
                }
                Rectangle { width: 1; Layout.preferredHeight: 36; color: root.border }
                ToolbarGroup {
                    title: "视图"
                    MbButton { appTheme: theme; text: "刷新"; iconText: "↻"; implicitWidth: 100; variant: "primary"; onClicked: bridge.refreshAll() }
                    MbButton { appTheme: theme; text: "清空筛选"; iconText: "×"; implicitWidth: 118; variant: "neutral"; onClicked: bridge.refreshAll() }
                }
                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: theme.panelBgAlt
            border.color: root.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 10

                MbStatusChip { appTheme: theme; label: "状态"; value: modeText(stateData.mode); type: stateData.state === "DEBUGGING_PAUSED" ? "warning" : (stateData.mode === "debug" ? "success" : "neutral"); Layout.preferredWidth: 140 }
                MbStatusChip { appTheme: theme; label: "Session"; value: stateData.sessionId || "请先新建会话"; type: stateData.hasSession ? "neutral" : "warning"; Layout.preferredWidth: 300; Layout.maximumWidth: 360 }
                MbStatusChip { appTheme: theme; label: "调用"; value: String(stateData.callCount || 0); type: "neutral"; Layout.preferredWidth: 104 }
                MbStatusChip { appTheme: theme; label: "接口"; value: String(stateData.discoveredInterfaceCount || 0); type: "neutral"; Layout.preferredWidth: 104 }
                MbStatusChip { appTheme: theme; label: "断点"; value: String(stateData.breakpointCount || 0); type: "neutral"; Layout.preferredWidth: 104 }
                MbStatusChip { appTheme: theme; label: "暂停"; value: String(stateData.pausedCount || 0); type: stateData.pausedCount > 0 ? "warning" : "neutral"; Layout.preferredWidth: 104 }
                RowLayout {
                    Layout.preferredWidth: 104
                    spacing: 6
                    Text {
                        text: "锁定接口"
                        color: stateData.interfaceLocked ? theme.warning : theme.textNormal
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    MbSwitch {
                        appTheme: theme
                        checked: !!stateData.interfaceLocked
                        onToggled: function(value) { bridge.setInterfaceLocked(value) }
                    }
                }
                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: stateData.pausedCount > 0 ? 42 : 0
            visible: stateData.pausedCount > 0
            color: theme.warningSoft
            border.color: theme.warning
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 12
                Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: theme.warning }
                Text {
                    text: "当前 Session 有 " + String(stateData.pausedCount || 0) + " 个请求命中断点并暂停"
                    color: theme.textStrong
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                MbButton {
                    appTheme: theme
                    text: "继续单个"
                    iconText: "▶"
                    enabled: root.selectedCallIsPaused()
                    variant: root.selectedCallIsPaused() ? "success" : "primary"
                    implicitWidth: 110
                    onClicked: bridge.continueCall(root.selectedCallId)
                }
                MbButton {
                    appTheme: theme
                    text: "继续全部"
                    iconText: "▶"
                    variant: "success"
                    implicitWidth: 110
                    onClicked: bridge.continueAll()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 168
                Layout.fillHeight: true
                color: theme.sidebarBg
                border.color: root.border

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredHeight: 8 }
                    MbNavButton { appTheme: theme; text: "接口列表"; iconText: "◇"; selected: currentPage === 0; onClicked: currentPage = 0 }
                    MbNavButton { appTheme: theme; text: "断点列表"; iconText: "◎"; selected: currentPage === 1; onClicked: currentPage = 1 }
                    MbNavButton { appTheme: theme; text: "调用记录"; iconText: "☷"; selected: currentPage === 2; onClicked: currentPage = 2 }
                    MbNavButton { appTheme: theme; text: "历史会话"; iconText: "◷"; selected: currentPage === 3; onClicked: currentPage = 3 }
                    Item { Layout.fillHeight: true }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: currentPage

                InterfacePage { appTheme: theme; items: interfaceItems; calls: callItems; breakpoints: breakpointItems }
                BreakpointPage {
                    appTheme: theme
                    items: breakpointItems
                    calls: callItems
                    onRequestCallFilter: function(breakpointId) {
                        root.callBreakpointFilter = breakpointId
                        root.currentPage = 2
                    }
                }
                CallRecordPage {
                    appTheme: theme
                    items: callItems
                    page: root.callListPage
                    pageSize: root.callListPageSize
                    total: root.callListTotal
                    breakpoints: breakpointItems
                    canClearRecords: stateData.mode === "idle" && stateData.hasSession
                    breakpointFilter: root.callBreakpointFilter
                    onClearBreakpointFilterRequested: root.callBreakpointFilter = ""
                    onSelectedCallChanged: function(callId, status) {
                        root.selectedCallId = callId
                        root.selectedCallStatus = status
                    }
                }
                SessionTab {
                    appTheme: theme
                    items: sessionItems
                    activeSessionId: stateData.sessionId || ""
                    canClearSessions: !stateData.debugging
                    debugging: !!stateData.debugging
                    pausedCount: Number(stateData.pausedCount || 0)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root.logExpanded ? 174 : 42
            color: theme.panelBgAlt
            border.color: root.border

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    spacing: 14

                    Row {
                        spacing: 8
                        Rectangle { width: 8; height: 8; radius: 4; color: root.green; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "连接: 本地调试后端"; color: root.textNormal; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle { width: 1; Layout.preferredHeight: 22; color: root.border }
                    Text { text: "应用: instrument-service-demo"; color: root.textMuted; font.pixelSize: 13; elide: Text.ElideRight }
                    Rectangle { width: 1; Layout.preferredHeight: 22; color: root.border }
                    Text { text: "环境: dev"; color: root.textMuted; font.pixelSize: 13 }
                    Rectangle { width: 1; Layout.preferredHeight: 22; color: root.border }
                    Text { text: "日志"; color: root.textStrong; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text {
                        text: root.logSummary()
                        color: resultText.length > 0 ? root.textNormal : root.textMuted
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    MbButton {
                        appTheme: theme
                        text: root.logExpanded ? "收起" : "展开"
                        variant: "neutral"
                        enabled: resultText.length > 0
                        implicitWidth: 72
                        Layout.preferredHeight: 30
                        onClicked: root.logExpanded = !root.logExpanded
                    }
                    Rectangle { width: 1; Layout.preferredHeight: 22; color: root.border }
                    Row {
                        spacing: 8
                        Rectangle { width: 8; height: 8; radius: 4; color: root.green; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "内存: 256M / 1024M"; color: root.textMuted; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                ScrollView {
                    visible: root.logExpanded
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    TextArea {
                        width: parent ? parent.width - 32 : 800
                        x: 16
                        y: 8
                        readOnly: true
                        selectByMouse: true
                        text: root.resultText
                        color: theme.codeText
                        selectedTextColor: theme.onAccent
                        selectionColor: theme.primary
                        font.family: "Consolas"
                        font.pixelSize: 12
                        wrapMode: TextEdit.Wrap
                        background: Rectangle { color: "transparent" }
                    }
                }
            }
        }
    }
}
