import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page
    property var appTheme
    property var items: []
    property var breakpoints: []
    property var selectedItem: items.length > 0 ? items[Math.max(0, list.currentIndex)] : null
    property color panel: appTheme.panelBg
    property color border: appTheme.border
    property color textStrong: appTheme.textStrong
    property color textNormal: appTheme.textNormal
    property color textMuted: appTheme.textMuted
    property color blue: appTheme.primary
    property color green: appTheme.success
    property color amber: appTheme.warning
    property color red: appTheme.danger

    function interfaceBreakpoint(interfaceId) {
        for (var i = 0; i < breakpoints.length; i++) {
            if (breakpoints[i].source_interface_id === interfaceId) return breakpoints[i]
        }
        return null
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
                        height: 88
                        color: list.currentIndex === index ? "#173052" : (index % 2 ? "#151c24" : "#111820")
                        border.color: border
                        MouseArea { anchors.fill: parent; onClicked: list.currentIndex = index }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 14
                            Rectangle { width: 10; height: 46; radius: 2; color: blue }
                            ColumnLayout {
                                Layout.preferredWidth: 330
                                Layout.fillHeight: true
                                spacing: 6
                                Item { Layout.fillHeight: true }
                                Text { text: modelData.method_name + "  " + (modelData.display_name || ""); color: textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: (modelData.http_method || "UNKNOWN") + " " + (modelData.request_uri || modelData.class_name || "-"); color: textMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                                Item { Layout.fillHeight: true }
                            }
                            Rectangle {
                                Layout.preferredWidth: 520
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                radius: 6
                                color: "#10161d"
                                border.color: "#2a5284"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12
                                    Text {
                                        text: "别名"
                                        color: "#8fbce8"
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                        Layout.preferredWidth: 38
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
                            RowLayout {
                                Layout.preferredWidth: 320
                                Layout.fillHeight: true
                                spacing: 12
                                Text { text: "调用 " + (modelData.call_count || 0); color: textNormal; font.pixelSize: 14; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignHCenter }
                                Text { text: "异常 " + (modelData.exception_count || 0); color: textMuted; font.pixelSize: 14; Layout.preferredWidth: 58; horizontalAlignment: Text.AlignHCenter }
                                MbTag {
                                    appTheme: page.appTheme
                                    Layout.preferredWidth: 78
                                    Layout.preferredHeight: 26
                                    text: boundBreakpoint ? (boundBreakpoint.enabled ? "断点启用" : "断点禁用") : "未设断点"
                                    type: boundBreakpoint ? (boundBreakpoint.enabled ? "success" : "warning") : "neutral"
                                }
                                MbSwitch {
                                    appTheme: page.appTheme
                                    visible: !!boundBreakpoint
                                    checked: boundBreakpoint ? !!boundBreakpoint.enabled : false
                                    onToggled: function(value) { bridge.setBreakpointEnabled(boundBreakpoint.id, value) }
                                }
                                MbButton {
                                    appTheme: page.appTheme
                                    text: boundBreakpoint ? "已设置" : "设置断点"
                                    variant: "primary"
                                    enabled: !boundBreakpoint
                                    Layout.preferredWidth: 82
                                    Layout.preferredHeight: 34
                                    onClicked: bridge.createBreakpointFromInterface(modelData.id)
                                }
                                MbButton {
                                    appTheme: page.appTheme
                                    visible: !!boundBreakpoint
                                    text: "×"
                                    variant: "danger"
                                    Layout.preferredWidth: 32
                                    Layout.preferredHeight: 34
                                    onClicked: bridge.deleteBreakpoint(boundBreakpoint.id)
                                }
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
