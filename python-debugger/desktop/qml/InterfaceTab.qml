import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page

    property var appTheme
    property var items: []
    property var breakpoints: []
    property var selectedItem: displayItems().length > 0 ? displayItems()[Math.max(0, list.currentIndex)] : null

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

    function slotText(item) {
        if (!item) return "-"
        if (item.slot_id === null || item.slot_id === undefined) return "无槽位"
        return String(item.slot_id)
    }

    function paramsSummary(item) {
        if (!item) return "-"
        return item.params_summary || JSON.stringify(item.latest_params || {})
    }

    function displayItems() {
        var result = items.slice()
        result.sort(function(a, b) {
            var objectCompare = String(a.object_name || "").localeCompare(String(b.object_name || ""))
            if (objectCompare !== 0) return objectCompare
            var cmdCompare = String(a.cmd_name || "").localeCompare(String(b.cmd_name || ""))
            if (cmdCompare !== 0) return cmdCompare
            return String(a.slot_key || "").localeCompare(String(b.slot_key || ""))
        })
        return result
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
                        model: page.displayItems()
                        clip: true
                        currentIndex: page.displayItems().length > 0 ? Math.max(0, currentIndex) : -1
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Item {
                            required property var modelData
                            required property int index

                            property var boundBreakpoint: page.interfaceBreakpoint(modelData.id)
                            property var previousItem: index > 0 ? list.model[index - 1] : null
                            property bool showGroupHeader: index === 0 || !previousItem || previousItem.object_name !== modelData.object_name

                            width: list.width
                            height: (showGroupHeader ? 34 : 0) + 112

                            Column {
                                anchors.fill: parent
                                Rectangle {
                                    width: parent.width
                                    height: showGroupHeader ? 34 : 0
                                    visible: showGroupHeader
                                    color: appTheme.panelBgAlt
                                    border.color: appTheme.borderSoft
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10
                                        Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: appTheme.primary }
                                        Text { text: modelData.object_name || "未归类对象"; color: appTheme.textStrong; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Text { text: "接口 " + items.filter(function(item) { return item.object_name === modelData.object_name }).length + " 个"; color: appTheme.textMuted; font.pixelSize: 12 }
                                    }
                                }
                                Rectangle {
                                    width: parent.width
                                    height: 112
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
                                            Layout.preferredHeight: 72
                                            radius: 2
                                            color: boundBreakpoint ? (boundBreakpoint.enabled ? appTheme.success : appTheme.warning) : appTheme.primary
                                        }

                                        ColumnLayout {
                                            Layout.preferredWidth: 260
                                            Layout.fillHeight: true
                                            spacing: 5

                                            Text {
                                                text: modelData.cmd_name || "-"
                                                color: appTheme.textStrong
                                                font.pixelSize: 16
                                                font.weight: Font.DemiBold
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: (modelData.object_name || "-") + " / 槽位 " + page.slotText(modelData)
                                                color: appTheme.textNormal
                                                font.pixelSize: 13
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                text: page.paramsSummary(modelData)
                                                color: appTheme.textMuted
                                                font.pixelSize: 12
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 280
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 66
                                            radius: 6
                                            color: appTheme.inputBg
                                            border.color: appTheme.inputBorder

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 4

                                                Text {
                                                    text: "业务别名"
                                                    color: appTheme.textMuted
                                                    font.pixelSize: 11
                                                    font.weight: Font.DemiBold
                                                }

                                                MbTextField {
                                                    appTheme: page.appTheme
                                                    Layout.fillWidth: true
                                                    Layout.preferredHeight: 32
                                                    text: modelData.interface_alias || ""
                                                    placeholderText: "为对象命令命名"
                                                    onEditingFinished: {
                                                        if (text !== (modelData.interface_alias || "")) {
                                                            bridge.setInterfaceAlias(modelData.id, text)
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.preferredWidth: 310
                                            Layout.fillHeight: true
                                            spacing: 8

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8

                                                MbStatusChip { appTheme: page.appTheme; label: "调用"; value: String(modelData.call_count || 0); type: "neutral"; Layout.preferredWidth: 70 }
                                                MbStatusChip { appTheme: page.appTheme; label: "样本"; value: String(modelData.params_sample_count || 0); type: (modelData.params_sample_count || 0) > 1 ? "primary" : "neutral"; Layout.preferredWidth: 70 }
                                                MbStatusChip { appTheme: page.appTheme; label: "异常"; value: String(modelData.exception_count || 0); type: (modelData.exception_count || 0) > 0 ? "danger" : "neutral"; Layout.preferredWidth: 70 }
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
                                                    text: boundBreakpoint ? "已设置" : "命令断点"
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
                            text: "开始调试后，通过脚本或业务流量触发 Java 接口"
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
