import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property var items: []
    property string activeSessionId: ""
    property bool canClearSessions: false
    property color panel: "#141a21"
    property color border: "#2a333d"
    property color textStrong: "#e8eef5"
    property color textNormal: "#c7d0da"
    property color textMuted: "#8b98a7"
    property color blue: "#2f81f7"
    property color green: "#55d66b"
    property color amber: "#f4d13d"

    function modeText(mode) {
        if (mode === "record") return "记录"
        if (mode === "debug") return "调试"
        return "空闲"
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: panel
        border.color: border
        radius: 3

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: panel
                border.color: border
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "历史会话"; color: textStrong; font.pixelSize: 17; font.weight: Font.DemiBold }
                        Text { text: activeSessionId ? "当前会话: " + activeSessionId : "请先新建会话，再开始记录或调试"; color: activeSessionId ? textMuted : amber; font.pixelSize: 13 }
                    }
                    Button {
                        text: "新建会话"
                        Layout.preferredWidth: 118
                        Layout.preferredHeight: 38
                        onClicked: bridge.createSession()
                        background: Rectangle { radius: 4; color: parent.hovered ? "#1f5fb9" : "#1d4f96"; border.color: "#58a6ff" }
                        contentItem: Text { text: parent.text; color: "#ffffff"; font.pixelSize: 14; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                    Button {
                        text: "清空历史"
                        enabled: page.canClearSessions && items.length > 0
                        Layout.preferredWidth: 118
                        Layout.preferredHeight: 38
                        onClicked: bridge.clearSessions()
                        background: Rectangle { radius: 4; color: parent.enabled ? (parent.hovered ? "#5a1f2a" : "#2b1720") : "#151b23"; border.color: parent.enabled ? "#7f2d3a" : "#222a33" }
                        contentItem: Text { text: parent.text; color: parent.enabled ? "#ffb4b4" : "#687483"; font.pixelSize: 14; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    }
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: items
                clip: true
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 76
                    color: modelData.id === activeSessionId ? "#173052" : (index % 2 ? "#151c24" : "#111820")
                    border.color: border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 14
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: modelData.id === activeSessionId ? green : textMuted
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text { text: modelData.id; color: textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text {
                                text: "应用 " + (modelData.service_name || "-") + " | 备注 " + (modelData.remark || "-")
                                color: textMuted
                                font.pixelSize: 12
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                        Text { text: modeText(modelData.mode); color: modelData.id === activeSessionId ? green : textNormal; font.pixelSize: 14; Layout.preferredWidth: 56 }
                        Text { text: "调用 " + (modelData.call_count || 0); color: textNormal; font.pixelSize: 14; Layout.preferredWidth: 72 }
                        Text { text: "接口 " + (modelData.interface_count || 0); color: textNormal; font.pixelSize: 14; Layout.preferredWidth: 72 }
                        Text { text: "异常 " + (modelData.exception_count || 0); color: textMuted; font.pixelSize: 14; Layout.preferredWidth: 72 }
                        Button {
                            text: modelData.id === activeSessionId ? "当前" : "选择"
                            enabled: modelData.id !== activeSessionId
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 34
                            onClicked: bridge.selectSession(modelData.id)
                            background: Rectangle { radius: 4; color: parent.enabled ? (parent.hovered ? "#1f5fb9" : "#1d4f96") : "#1a2430"; border.color: parent.enabled ? "#58a6ff" : border }
                            contentItem: Text { text: parent.text; color: parent.enabled ? "#ffffff" : textMuted; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }
        }
    }
}
