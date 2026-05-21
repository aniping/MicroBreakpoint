import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 1200
    height: 800
    title: "MicroBreakpoint - Java 微服务接口断点调试器"

    property var stateData: ({mode: "idle", callCount: 0, discoveredInterfaceCount: 0, breakpointCount: 0, pausedCount: 0})
    property var callItems: []
    property var interfaceItems: []
    property var breakpointItems: []
    property string resultText: ""

    Component.onCompleted: bridge.refreshAll()

    Connections {
        target: bridge
        function onStateChanged(payload) { stateData = JSON.parse(payload) }
        function onCallsChanged(payload) { callItems = JSON.parse(payload).items || [] }
        function onInterfacesChanged(payload) { interfaceItems = JSON.parse(payload).items || [] }
        function onBreakpointsChanged(payload) { breakpointItems = JSON.parse(payload).items || [] }
        function onResultChanged(payload) { resultText = payload }
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

        ToolBar {
            Layout.fillWidth: true
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Button { text: "开始记录"; enabled: stateData.mode === "idle"; onClicked: bridge.startRecord() }
                Button { text: "停止记录"; enabled: stateData.mode === "record"; onClicked: bridge.stopRecord() }
                Button { text: "开始调试"; enabled: stateData.mode === "idle"; onClicked: bridge.startDebug() }
                Button { text: "停止调试"; enabled: stateData.mode === "debug"; onClicked: bridge.stopDebug() }
                Button { text: "刷新"; onClicked: bridge.refreshAll() }
                Button { text: "继续全部"; enabled: stateData.pausedCount > 0; onClicked: bridge.continueAll() }
                Item { Layout.fillWidth: true }
                Label {
                    text: "状态: " + stateData.mode + " | Session: " + (stateData.sessionId || "-") +
                          " | 调用: " + stateData.callCount + " | 接口: " + stateData.discoveredInterfaceCount +
                          " | 断点: " + stateData.breakpointCount + " | 暂停: " + stateData.pausedCount
                }
            }
        }

        TabBar {
            id: tabs
            Layout.fillWidth: true
            TabButton { text: "调用记录" }
            TabButton { text: "已发现接口" }
            TabButton { text: "断点管理" }
            TabButton { text: "历史会话" }
            TabButton { text: "Java 调用" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabs.currentIndex

            CallRecordTab { items: callItems }
            InterfaceTab { items: interfaceItems }
            BreakpointTab { items: breakpointItems }
            SessionTab {}
            JavaCallTab { resultText: root.resultText }
        }
    }
}
