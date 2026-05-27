import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page

    property var appTheme
    property var items: []
    property var selectedItem: items.length > 0 ? items[Math.max(0, list.currentIndex)] : null

    function conditionSummary(condition) {
        var data = condition || {}
        var keys = Object.keys(data)
        if (keys.length === 0) return "无条件"
        var parts = []
        for (var i = 0; i < Math.min(keys.length, 3); i++) {
            parts.push(keys[i] + " = " + data[keys[i]])
        }
        if (keys.length > 3) parts.push("...")
        return parts.join(", ")
    }

    function slotText(item) {
        if (!item) return "-"
        if (item.slot_id === null || item.slot_id === undefined) return "无槽位"
        return String(item.slot_id)
    }

    function matchModeText(mode) {
        if (mode === "params_snapshot") return "参数快照"
        if (mode === "params_condition") return "参数条件"
        return "命令"
    }

    function matchSummary(item) {
        if (!item) return "-"
        if (item.match_mode === "params_snapshot") return "参数快照: " + JSON.stringify(item.params_snapshot || {})
        if (item.match_mode === "params_condition") return "参数条件: " + page.conditionSummary(item.condition)
        return "命令匹配: " + (item.object_name || "-") + " / " + (item.cmd_name || "-")
    }

    function breakpointScopeText(item) {
        if (!item) return "-"
        var text = (item.object_name || "-") + " / " + (item.cmd_name || "-")
        if ((item.match_mode || "command_only") !== "command_only") text += " / 槽位 " + page.slotText(item)
        return text
    }

    function breakpointName(item) {
        if (!item) return "-"
        var name = item.name || ((item.object_name || "-") + " / " + (item.cmd_name || "-"))
        if (String(name).toLowerCase().endsWith(" breakpoint")) name = String(name).slice(0, -11)
        return name
    }

    function sourceText(item) {
        if (!item) return "-"
        if (item.source_call_id) return "调用记录"
        if (item.source_interface_id || item.resolved_interface_id) return "已发现接口"
        if (item.source_session_id) return "会话"
        return "手动"
    }

    function confirmDeleteBreakpoint(item) {
        var breakpointId = item ? item.id : ""
        var breakpointName = item ? page.breakpointName(item) : breakpointId
        confirmDialog.ask("删除断点", "将删除断点 " + breakpointName + "。此操作不可撤销。", "删除", function() {
            bridge.deleteBreakpoint(breakpointId)
        })
    }

    ConfirmDialog {
        id: confirmDialog
        appTheme: page.appTheme
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
                        Text {
                            text: "断点管理"
                            color: appTheme.textStrong
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        MbTag { appTheme: page.appTheme; text: "共 " + items.length + " 个"; type: "primary" }
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

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: list.width
                            height: 118
                            color: modelData.enabled
                                   ? (list.currentIndex === index ? appTheme.panelActive : (index % 2 ? appTheme.panelBgAlt : appTheme.panelBg))
                                   : appTheme.panelBgAlt
                            border.color: appTheme.borderSoft
                            opacity: modelData.enabled ? 1 : 0.68

                            MouseArea {
                                anchors.fill: parent
                                onClicked: list.currentIndex = index
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 14

                                Rectangle {
                                    Layout.preferredWidth: 4
                                    Layout.preferredHeight: 74
                                    radius: 2
                                    color: modelData.enabled ? appTheme.success : appTheme.textMuted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 5

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        MbTag { appTheme: page.appTheme; text: modelData.enabled ? "启用" : "禁用"; type: modelData.enabled ? "success" : "neutral"; Layout.preferredWidth: 60 }
                                        Text {
                                            text: page.breakpointName(modelData)
                                            color: appTheme.textStrong
                                            font.pixelSize: 16
                                            font.weight: Font.DemiBold
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Text {
                                        text: page.breakpointScopeText(modelData) + " / Session " + (modelData.session_id || "-")
                                        color: appTheme.textNormal
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: page.matchSummary(modelData)
                                        color: appTheme.textMuted
                                        font.pixelSize: 12
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        MbStatusChip { appTheme: page.appTheme; label: "匹配"; value: page.matchModeText(modelData.match_mode); type: modelData.match_mode === "params_snapshot" ? "primary" : "neutral"; Layout.preferredWidth: 118 }
                                        MbStatusChip { appTheme: page.appTheme; label: "命中"; value: String(modelData.hit_count || 0); type: (modelData.hit_count || 0) > 0 ? "warning" : "neutral"; Layout.preferredWidth: 92 }
                                        MbStatusChip { appTheme: page.appTheme; label: "来源"; value: page.sourceText(modelData); type: "neutral"; Layout.preferredWidth: 126 }
                                        MbStatusChip { appTheme: page.appTheme; label: "创建"; value: String(modelData.created_at || "-").replace("T", " ").split("+")[0]; type: "neutral"; Layout.fillWidth: true }
                                    }
                                }

                                ColumnLayout {
                                    Layout.preferredWidth: 118
                                    spacing: 8
                                    MbSwitch {
                                        appTheme: page.appTheme
                                        checked: !!modelData.enabled
                                        Layout.alignment: Qt.AlignHCenter
                                        onToggled: function(value) { bridge.setBreakpointEnabled(modelData.id, value) }
                                    }
                                    MbButton {
                                        appTheme: page.appTheme
                                        text: "编辑条件"
                                        enabled: false
                                        variant: "neutral"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                    }
                                    MbButton {
                                        appTheme: page.appTheme
                                        text: "删除"
                                        variant: "danger"
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 32
                                        onClicked: page.confirmDeleteBreakpoint(modelData)
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
                            text: "暂无断点"
                            color: appTheme.textStrong
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "可从已发现接口或调用记录创建断点"
                            color: appTheme.textMuted
                            font.pixelSize: 13
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
                        text: "断点详情"
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
