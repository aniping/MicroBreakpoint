import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"
import "theme"

ApplicationWindow {
    id: root
    visible: true
    width: 1448
    height: 1070
    minimumWidth: 1100
    minimumHeight: 760
    title: "MicroBreakpoint - Java 微服务接口断点调试器"
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

    property int currentPage: 3
    property var stateData: ({mode: "idle", callCount: 0, discoveredInterfaceCount: 0, breakpointCount: 0, pausedCount: 0})
    property var callItems: []
    property var interfaceItems: []
    property var breakpointItems: []
    property var sessionItems: []
    property string resultText: ""

    AppTheme {
        id: theme
        mode: root.themeMode
    }

    function modeText(mode) {
        if (mode === "record") return "记录中"
        if (mode === "debug") return "调试中"
        return "空闲"
    }

    function modeColor(mode) {
        if (mode === "record") return root.blue
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
        function onCallsChanged(payload) { callItems = JSON.parse(payload).items || [] }
        function onInterfacesChanged(payload) { interfaceItems = JSON.parse(payload).items || [] }
        function onBreakpointsChanged(payload) { breakpointItems = JSON.parse(payload).items || [] }
        function onSessionsChanged(payload) { sessionItems = JSON.parse(payload).items || [] }
        function onResultChanged(payload) { resultText = payload }
        function onThemeChanged(mode) { root.themeMode = mode }
    }

    Timer {
        running: true
        repeat: true
        interval: 1500
        onTriggered: bridge.refreshAll()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 45
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
                    Text { anchors.centerIn: parent; text: "M"; color: "white"; font.bold: true; font.pixelSize: 13 }
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
                    onClicked: bridge.setThemeMode(root.themeMode === "dark" ? "light" : "dark")
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
            Layout.preferredHeight: 70
            color: theme.toolbarBg
            border.color: root.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 30
                spacing: 18
                MbButton { appTheme: theme; text: "新建会话"; iconText: "+"; variant: "primary"; implicitWidth: 122; enabled: stateData.mode === "idle"; onClicked: { bridge.createSession(); currentPage = 3 } }
                MbButton { appTheme: theme; text: "开始记录"; iconText: "●"; variant: "success"; enabled: stateData.mode === "idle" && stateData.hasSession; onClicked: bridge.startRecord() }
                MbButton { appTheme: theme; text: "停止记录"; iconText: "■"; variant: "danger"; enabled: stateData.mode === "record"; onClicked: bridge.stopRecord() }
                MbButton { appTheme: theme; text: "开始调试"; iconText: "▶"; variant: "primary"; enabled: stateData.mode === "idle" && stateData.hasSession; onClicked: bridge.startDebug() }
                MbButton { appTheme: theme; text: "停止调试"; iconText: "■"; variant: "danger"; enabled: stateData.mode === "debug"; onClicked: bridge.stopDebug() }
                Rectangle { width: 1; Layout.preferredHeight: 36; color: root.border }
                MbButton { appTheme: theme; text: "刷新"; iconText: "↻"; implicitWidth: 102; variant: "primary"; onClicked: bridge.refreshAll() }
                MbButton { appTheme: theme; text: "继续全部"; iconText: "▶"; variant: "primary"; enabled: stateData.pausedCount > 0; onClicked: bridge.continueAll() }
                MbButton { appTheme: theme; text: "清空筛选"; iconText: "×"; implicitWidth: 124; variant: "neutral"; onClicked: bridge.refreshAll() }
                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: theme.panelBgAlt
            border.color: root.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 10

                MbStatusChip { appTheme: theme; label: "状态"; value: modeText(stateData.mode); type: stateData.mode === "debug" ? "success" : (stateData.mode === "record" ? "primary" : "neutral"); Layout.preferredWidth: 140 }
                MbStatusChip { appTheme: theme; label: "Session"; value: stateData.sessionId || "请先新建会话"; type: stateData.hasSession ? "neutral" : "warning"; Layout.preferredWidth: 300; Layout.maximumWidth: 360 }
                MbStatusChip { appTheme: theme; label: "调用"; value: String(stateData.callCount || 0); type: "neutral"; Layout.preferredWidth: 104 }
                MbStatusChip { appTheme: theme; label: "接口"; value: String(stateData.discoveredInterfaceCount || 0); type: "neutral"; Layout.preferredWidth: 104 }
                MbStatusChip { appTheme: theme; label: "断点"; value: String(stateData.breakpointCount || 0); type: "neutral"; Layout.preferredWidth: 104 }
                MbStatusChip { appTheme: theme; label: "暂停"; value: String(stateData.pausedCount || 0); type: stateData.pausedCount > 0 ? "warning" : "neutral"; Layout.preferredWidth: 104 }
                Item { Layout.fillWidth: true }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                Layout.preferredWidth: 152
                Layout.fillHeight: true
                color: theme.sidebarBg
                border.color: root.border

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredHeight: 8 }
                    MbNavButton { appTheme: theme; text: "调用记录"; iconText: "☷"; selected: currentPage === 0; onClicked: currentPage = 0 }
                    MbNavButton { appTheme: theme; text: "已发现接口"; iconText: "◇"; selected: currentPage === 1; onClicked: currentPage = 1 }
                    MbNavButton { appTheme: theme; text: "断点管理"; iconText: "◎"; selected: currentPage === 2; onClicked: currentPage = 2 }
                    MbNavButton { appTheme: theme; text: "历史会话"; iconText: "◷"; selected: currentPage === 3; onClicked: currentPage = 3 }
                    MbNavButton { appTheme: theme; text: "Java调用"; iconText: "J"; selected: currentPage === 4; onClicked: currentPage = 4 }
                    Item { Layout.fillHeight: true }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.border }
                    MbNavButton { appTheme: theme; text: "设置"; iconText: "⚙"; selected: currentPage === 5; onClicked: currentPage = 5 }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: currentPage

                CallRecordTab { items: callItems; breakpoints: breakpointItems; canClearRecords: stateData.mode === "idle" && stateData.hasSession }
                InterfaceTab { items: interfaceItems; breakpoints: breakpointItems }
                BreakpointTab { items: breakpointItems }
                SessionTab { items: sessionItems; activeSessionId: stateData.sessionId || ""; canClearSessions: stateData.mode === "idle" }
                JavaCallTab { appTheme: theme; resultText: root.resultText }
                SettingsTab {}
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: theme.panelBgAlt
            border.color: root.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 18
                Row {
                    spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: root.green; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "连接: 本地调试后端"; color: root.textNormal; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle { width: 1; Layout.preferredHeight: 22; color: root.border }
                Text { text: "应用: instrument-service-demo"; color: root.textMuted; font.pixelSize: 13 }
                Rectangle { width: 1; Layout.preferredHeight: 22; color: root.border }
                Text { text: "环境: dev"; color: root.textMuted; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text { text: "日志"; color: root.textMuted; font.pixelSize: 13 }
                Rectangle { width: 1; Layout.preferredHeight: 22; color: root.border }
                Row {
                    spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: root.green; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "内存: 256M / 1024M"; color: root.textMuted; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
