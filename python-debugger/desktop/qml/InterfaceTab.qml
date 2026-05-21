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

    function interfaceBreakpoint(interfaceId) {
        for (var i = 0; i < breakpoints.length; i++) {
            if (breakpoints[i].source_interface_id === interfaceId) return breakpoints[i]
        }
        return null
    }

    function breakpointText(breakpoint) {
        if (!breakpoint) return "未设断点"
        return breakpoint.enabled ? "断点启用" : "断点禁用"
    }

    function breakpointType(breakpoint) {
        if (!breakpoint) return "neutral"
        return breakpoint.enabled ? "success" : "warning"
    }

    function rowColor(selected, index) {
        if (selected) return appTheme.panelActive
        return index % 2 ? appTheme.panelBgAlt : appTheme.panelBg
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        MbPanel {
            appTheme: page.appTheme
            padding: 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    color: appTheme.panelBg
                    border.color: appTheme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 12

                        Text {
                            text: "已发现接口"
                            color: appTheme.textStrong
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            verticalAlignment: Text.AlignVCenter
                        }

                        MbTag {
                            appTheme: page.appTheme
                            text: "共 " + items.length + " 个"
                            type: "primary"
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
                        currentIndex: items.length > 0 ? Math.max(0, currentIndex) : -1
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            property var boundBreakpoint: page.interfaceBreakpoint(modelData.id)

                            width: list.width
                            height: 104
                            color: page.rowColor(list.currentIndex === index, index)
                            border.color: appTheme.borderSoft

                            MouseArea {
                                anchors.fill: parent
                                onClicked: list.currentIndex = index
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 16

                                Rectangle {
                                    Layout.preferredWidth: 4
                                    Layout.preferredHeight: 64
                                    radius: 2
                                    color: boundBreakpoint ? (boundBreakpoint.enabled ? appTheme.success : appTheme.warning) : appTheme.primary
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 330
                                    Layout.fillHeight: true
                                    spacing: 5

                                    Text {
                                        text: modelData.method_name || "-"
                                        color: appTheme.textStrong
                                        font.pixelSize: 16
                                        font.weight: Font.DemiBold
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: modelData.display_name || modelData.class_name || "-"
                                        color: appTheme.textNormal
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: (modelData.http_method || "UNKNOWN") + "  " + (modelData.request_uri || modelData.class_name || "-")
                                        color: appTheme.textMuted
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 360
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 62
                                    radius: 6
                                    color: appTheme.inputBg
                                    border.color: appTheme.inputBorder

                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 4

                                        Text {
                                            text: "别名"
                                            color: appTheme.textMuted
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                        }

                                        MbTextField {
                                            appTheme: page.appTheme
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 32
                                            text: modelData.interface_alias || ""
                                            placeholderText: "为接口命名"
                                            onEditingFinished: {
                                                if (text !== (modelData.interface_alias || "")) {
                                                    bridge.setInterfaceAlias(modelData.id, text)
                                                }
                                            }
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 300
                                    Layout.fillHeight: true
                                    spacing: 8

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        MbStatusChip { appTheme: page.appTheme; label: "调用"; value: String(modelData.call_count || 0); type: "neutral"; Layout.preferredWidth: 84 }
                                        MbStatusChip { appTheme: page.appTheme; label: "异常"; value: String(modelData.exception_count || 0); type: (modelData.exception_count || 0) > 0 ? "danger" : "neutral"; Layout.preferredWidth: 84 }
                                        MbTag { appTheme: page.appTheme; text: page.breakpointText(boundBreakpoint); type: page.breakpointType(boundBreakpoint); Layout.preferredWidth: 86 }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

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
                                            Layout.preferredWidth: 92
                                            Layout.preferredHeight: 34
                                            onClicked: bridge.createBreakpointFromInterface(modelData.id)
                                        }

                                        MbButton {
                                            appTheme: page.appTheme
                                            visible: !!boundBreakpoint
                                            text: "删除"
                                            variant: "danger"
                                            Layout.preferredWidth: 72
                                            Layout.preferredHeight: 34
                                            onClicked: bridge.deleteBreakpoint(boundBreakpoint.id)
                                        }

                                        Item { Layout.fillWidth: true }
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
                            text: "暂无已发现接口"
                            color: appTheme.textStrong
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                        }

                        Text {
                            text: "开始记录或调试后，在 Java 调用页主动触发 Demo 接口"
                            color: appTheme.textMuted
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }

        MbPanel {
            appTheme: page.appTheme
            padding: 0
            Layout.preferredWidth: 430
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    color: appTheme.panelBg
                    border.color: appTheme.border

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        text: "接口详情"
                        color: appTheme.textStrong
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }

                MbJsonViewer {
                    appTheme: page.appTheme
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: selectedItem ? JSON.stringify(selectedItem, null, 2) : "{}"
                }
            }
        }
    }
}
