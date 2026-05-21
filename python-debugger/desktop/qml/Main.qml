import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1448
    height: 1070
    minimumWidth: 1100
    minimumHeight: 760
    title: "MicroBreakpoint - Java 微服务接口断点调试器"
    color: "#0d1218"

    property color bg: "#0d1218"
    property color panel: "#141a21"
    property color panel2: "#10161d"
    property color border: "#2a333d"
    property color textStrong: "#e8eef5"
    property color textNormal: "#c7d0da"
    property color textMuted: "#8b98a7"
    property color blue: "#2f81f7"
    property color green: "#55d66b"
    property color red: "#ff5d5d"
    property color amber: "#f4d13d"

    property int currentPage: 3
    property var stateData: ({mode: "idle", callCount: 0, discoveredInterfaceCount: 0, breakpointCount: 0, pausedCount: 0})
    property var callItems: []
    property var interfaceItems: []
    property var breakpointItems: []
    property var sessionItems: []
    property string resultText: ""

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

    Component.onCompleted: bridge.refreshAll()

    Connections {
        target: bridge
        function onStateChanged(payload) { stateData = JSON.parse(payload) }
        function onCallsChanged(payload) { callItems = JSON.parse(payload).items || [] }
        function onInterfacesChanged(payload) { interfaceItems = JSON.parse(payload).items || [] }
        function onBreakpointsChanged(payload) { breakpointItems = JSON.parse(payload).items || [] }
        function onSessionsChanged(payload) { sessionItems = JSON.parse(payload).items || [] }
        function onResultChanged(payload) { resultText = payload }
    }

    Timer {
        running: true
        repeat: true
        interval: 1500
        onTriggered: bridge.refreshAll()
    }

    component MbButton: Button {
        id: btn
        implicitWidth: 132
        implicitHeight: 44
        padding: 0
        font.pixelSize: 15
        font.weight: Font.Medium
        property color accent: root.blue
        contentItem: Row {
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                width: 15
                height: 15
                radius: 3
                color: btn.enabled ? btn.accent : "#47515d"
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: btn.text
                color: btn.enabled ? root.textStrong : "#687483"
                font: btn.font
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        background: Rectangle {
            radius: 4
            color: btn.pressed ? "#243344" : (btn.hovered ? "#1d2631" : "#151b23")
            border.color: btn.enabled ? "#323d49" : "#222a33"
        }
    }

    component NavButton: Button {
        id: nav
        property string label: ""
        property string iconText: ""
        property bool selected: false
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        padding: 0
        background: Rectangle {
            color: nav.selected ? "#18365e" : (nav.hovered ? "#121c28" : "transparent")
            border.color: nav.selected ? "#245fa8" : "transparent"
            Rectangle {
                width: 3
                height: parent.height
                visible: nav.selected
                color: root.blue
                anchors.left: parent.left
            }
        }
        contentItem: Item {
            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 22
                spacing: 12
                Text { text: nav.iconText; color: nav.selected ? "#58a6ff" : "#a6b2c0"; font.pixelSize: 20; anchors.verticalCenter: parent.verticalCenter }
                Text { text: nav.label; color: nav.selected ? "#cfe6ff" : "#c4ccd6"; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 45
            color: "#0f151c"
            border.color: "#232c36"
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
                        GradientStop { position: 0; color: "#58a6ff" }
                        GradientStop { position: 1; color: "#1f6feb" }
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
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: "#141a21"
            border.color: root.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 30
                anchors.rightMargin: 30
                spacing: 18
                MbButton { text: "新建会话"; accent: root.blue; implicitWidth: 122; enabled: stateData.mode === "idle"; onClicked: { bridge.createSession(); currentPage = 3 } }
                MbButton { text: "开始记录"; accent: root.green; enabled: stateData.mode === "idle" && stateData.hasSession; onClicked: bridge.startRecord() }
                MbButton { text: "停止记录"; accent: root.red; enabled: stateData.mode === "record"; onClicked: bridge.stopRecord() }
                MbButton { text: "开始调试"; accent: root.blue; enabled: stateData.mode === "idle" && stateData.hasSession; onClicked: bridge.startDebug() }
                MbButton { text: "停止调试"; accent: root.red; enabled: stateData.mode === "debug"; onClicked: bridge.stopDebug() }
                Rectangle { width: 1; Layout.preferredHeight: 36; color: root.border }
                MbButton { text: "刷新"; implicitWidth: 102; accent: root.blue; onClicked: bridge.refreshAll() }
                MbButton { text: "继续全部"; accent: root.blue; enabled: stateData.pausedCount > 0; onClicked: bridge.continueAll() }
                MbButton { text: "清空筛选"; implicitWidth: 124; accent: "#94a3b8"; onClicked: bridge.refreshAll() }
                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: "#10161d"
            border.color: root.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 30

                Row {
                    spacing: 8
                    Layout.preferredWidth: 150
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 9; height: 9; radius: 5; color: modeColor(stateData.mode); anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "状态:"; color: root.textNormal; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: modeText(stateData.mode); color: modeColor(stateData.mode); font.bold: true; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                }
                Rectangle { width: 1; Layout.preferredHeight: 28; color: root.border }
                Text { text: "Session:  " + (stateData.sessionId || "请先新建会话"); color: stateData.hasSession ? root.textNormal : root.amber; font.pixelSize: 15 }
                Rectangle { width: 1; Layout.preferredHeight: 28; color: root.border }
                Text { text: "调用:  " + stateData.callCount; color: root.textStrong; font.pixelSize: 15 }
                Rectangle { width: 1; Layout.preferredHeight: 28; color: root.border }
                Text { text: "接口:  " + stateData.discoveredInterfaceCount; color: root.textStrong; font.pixelSize: 15 }
                Rectangle { width: 1; Layout.preferredHeight: 28; color: root.border }
                Text { text: "断点:  " + stateData.breakpointCount; color: root.textStrong; font.pixelSize: 15 }
                Rectangle { width: 1; Layout.preferredHeight: 28; color: root.border }
                Text { text: "暂停:  " + stateData.pausedCount; color: stateData.pausedCount > 0 ? root.amber : root.textStrong; font.bold: stateData.pausedCount > 0; font.pixelSize: 15 }
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
                color: "#10171f"
                border.color: root.border

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    Item { Layout.preferredHeight: 8 }
                    NavButton { label: "调用记录"; iconText: "☷"; selected: currentPage === 0; onClicked: currentPage = 0 }
                    NavButton { label: "已发现接口"; iconText: "◇"; selected: currentPage === 1; onClicked: currentPage = 1 }
                    NavButton { label: "断点管理"; iconText: "◎"; selected: currentPage === 2; onClicked: currentPage = 2 }
                    NavButton { label: "历史会话"; iconText: "◷"; selected: currentPage === 3; onClicked: currentPage = 3 }
                    NavButton { label: "Java调用"; iconText: "J"; selected: currentPage === 4; onClicked: currentPage = 4 }
                    Item { Layout.fillHeight: true }
                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.border }
                    NavButton { label: "设置"; iconText: "⚙"; selected: currentPage === 5; onClicked: currentPage = 5 }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: currentPage

                CallRecordTab { items: callItems; breakpoints: breakpointItems; canClearRecords: stateData.mode === "idle" && stateData.hasSession }
                InterfaceTab { items: interfaceItems }
                BreakpointTab { items: breakpointItems }
                SessionTab { items: sessionItems; activeSessionId: stateData.sessionId || ""; canClearSessions: stateData.mode === "idle" }
                JavaCallTab { resultText: root.resultText }
                SettingsTab {}
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            color: "#111820"
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
