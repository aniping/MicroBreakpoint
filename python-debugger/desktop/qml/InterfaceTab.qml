import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property var items: []
    property var breakpoints: []
    property var selectedItem: items.length > 0 ? items[Math.max(0, list.currentIndex)] : null
    property color panel: "#141a21"
    property color border: "#2a333d"
    property color textStrong: "#e8eef5"
    property color textNormal: "#c7d0da"
    property color textMuted: "#8b98a7"
    property color blue: "#2f81f7"
    property color green: "#55d66b"
    property color amber: "#f4d13d"
    property color red: "#ff5d5d"

    function interfaceBreakpoint(interfaceId) {
        for (var i = 0; i < breakpoints.length; i++) {
            if (breakpoints[i].source_interface_id === interfaceId) return breakpoints[i]
        }
        return null
    }

    component MiniSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled(bool checked)
        width: 42
        height: 22
        radius: 11
        color: checked ? "#1f6feb" : "#26313d"
        border.color: checked ? "#58a6ff" : "#4b5563"
        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: "#e8eef5"
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? 22 : 4
            Behavior on x { NumberAnimation { duration: 110 } }
        }
        MouseArea { anchors.fill: parent; onClicked: sw.toggled(!sw.checked) }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: panel
            border.color: border
            radius: 3
            ColumnLayout {
                anchors.fill: parent
                spacing: 0
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    color: panel
                    border.color: border
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 16; text: "已发现接口"; color: textStrong; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 16; text: "共 " + items.length + " 个"; color: textMuted; font.pixelSize: 14 }
                }
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: items
                    clip: true
                    currentIndex: items.length > 0 ? Math.max(0, currentIndex) : -1
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        property var boundBreakpoint: page.interfaceBreakpoint(modelData.id)
                        width: list.width
                        height: 108
                        color: list.currentIndex === index ? "#173052" : (index % 2 ? "#151c24" : "#111820")
                        border.color: border
                        MouseArea { anchors.fill: parent; onClicked: list.currentIndex = index }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            Rectangle { width: 10; height: 36; radius: 2; color: blue }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                Text { text: modelData.method_name + "  " + (modelData.display_name || ""); color: textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 36
                                    radius: 6
                                    color: "#10161d"
                                    border.color: "#2a5284"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 10
                                        Text {
                                            text: "别名"
                                            color: "#8fbce8"
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                            Layout.preferredWidth: 34
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        TextField {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            text: modelData.interface_alias || ""
                                            placeholderText: "为接口命名，便于调用记录和断点识别"
                                            color: textStrong
                                            placeholderTextColor: textMuted
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            selectByMouse: true
                                            onEditingFinished: {
                                                if (text !== (modelData.interface_alias || "")) {
                                                    bridge.setInterfaceAlias(modelData.id, text)
                                                }
                                            }
                                            background: Rectangle { color: "transparent" }
                                        }
                                    }
                                }
                                Text { text: modelData.class_name || "-"; color: textMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            Text { text: "调用 " + (modelData.call_count || 0); color: textNormal; font.pixelSize: 14 }
                            Text { text: "异常 " + (modelData.exception_count || 0); color: textMuted; font.pixelSize: 14 }
                            Rectangle {
                                Layout.preferredWidth: 78
                                Layout.preferredHeight: 26
                                radius: 4
                                color: boundBreakpoint ? (boundBreakpoint.enabled ? "#153d24" : "#3c3617") : "#202733"
                                border.color: boundBreakpoint ? (boundBreakpoint.enabled ? green : amber) : "#4b5563"
                                Text {
                                    anchors.centerIn: parent
                                    text: boundBreakpoint ? (boundBreakpoint.enabled ? "断点启用" : "断点禁用") : "未设断点"
                                    color: boundBreakpoint ? (boundBreakpoint.enabled ? green : amber) : textMuted
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }
                            MiniSwitch {
                                visible: !!boundBreakpoint
                                checked: boundBreakpoint ? !!boundBreakpoint.enabled : false
                                onToggled: function(value) { bridge.setBreakpointEnabled(boundBreakpoint.id, value) }
                            }
                            Button {
                                text: boundBreakpoint ? "已设置" : "设置断点"
                                enabled: !boundBreakpoint
                                Layout.preferredWidth: 88
                                Layout.preferredHeight: 34
                                onClicked: bridge.createBreakpointFromInterface(modelData.id)
                                background: Rectangle { radius: 4; color: parent.enabled ? (parent.hovered ? "#1f5fb9" : "#1d4f96") : "#1a2430"; border.color: parent.enabled ? "#58a6ff" : border }
                                contentItem: Text { text: parent.text; color: parent.enabled ? "#ffffff" : textMuted; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            Button {
                                visible: !!boundBreakpoint
                                text: "×"
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 34
                                onClicked: bridge.deleteBreakpoint(boundBreakpoint.id)
                                background: Rectangle { radius: 4; color: parent.hovered ? "#5a1f2a" : "#2b1720"; border.color: "#7f2d3a" }
                                contentItem: Text { text: parent.text; color: "#ffb4b4"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }
            }
        }

        DetailPanel {
            Layout.preferredWidth: 430
            Layout.fillHeight: true
            title: "接口详情"
            text: selectedItem ? JSON.stringify(selectedItem, null, 2) : "选择一个接口"
        }
    }
}
