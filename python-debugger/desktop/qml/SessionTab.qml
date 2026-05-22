import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page
    property var appTheme
    property var items: []
    property string activeSessionId: ""
    property bool canClearSessions: false

    function modeText(mode) {
        if (mode === "record") return "记录"
        if (mode === "debug") return "调试"
        return "空闲"
    }

    function modeType(mode) {
        if (mode === "record") return "primary"
        if (mode === "debug") return "success"
        return "neutral"
    }

    function compactTime(value) {
        if (!value) return "-"
        return String(value).replace("T", " ").split("+")[0]
    }

    function currentHint() {
        return activeSessionId ? "当前 Session: " + activeSessionId : "请先新建 Session，再开始调试"
    }

    MbPanel {
        appTheme: page.appTheme
        padding: 0
        anchors.fill: parent
        anchors.margins: 12

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                color: appTheme.panelBg
                border.color: appTheme.border

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "历史会话"
                            color: appTheme.textStrong
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: page.currentHint()
                            color: activeSessionId ? appTheme.textMuted : appTheme.warning
                            font.pixelSize: 13
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }
                    }

                    MbButton {
                        appTheme: page.appTheme
                        text: "新建会话"
                        iconText: "+"
                        variant: "primary"
                        Layout.preferredWidth: 118
                        Layout.preferredHeight: 38
                        onClicked: bridge.createSession()
                    }

                    MbButton {
                        appTheme: page.appTheme
                        text: "清空历史"
                        iconText: "×"
                        variant: "danger"
                        enabled: page.canClearSessions && items.length > 0
                        Layout.preferredWidth: 118
                        Layout.preferredHeight: 38
                        onClicked: bridge.clearSessions()
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
                    spacing: 0

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: list.width
                        height: 132
                        color: modelData.id === activeSessionId ? appTheme.panelActive : (index % 2 ? appTheme.panelBgAlt : appTheme.panelBg)
                        border.color: appTheme.borderSoft

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 14

                            Rectangle {
                                Layout.preferredWidth: 4
                                Layout.preferredHeight: 84
                                radius: 2
                                color: modelData.id === activeSessionId ? appTheme.success : appTheme.textMuted
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 7

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    MbTag {
                                        appTheme: page.appTheme
                                        text: page.modeText(modelData.mode)
                                        type: page.modeType(modelData.mode)
                                    }

                                    Text {
                                        text: modelData.id
                                        color: appTheme.textStrong
                                        font.pixelSize: 15
                                        font.weight: Font.DemiBold
                                        Layout.fillWidth: true
                                        elide: Text.ElideMiddle
                                    }

                                    MbTag {
                                        visible: modelData.id === activeSessionId
                                        appTheme: page.appTheme
                                        text: "当前会话"
                                        type: "success"
                                    }
                                }

                                Text {
                                    text: "服务: " + (modelData.service_name || "-") + "    备注: " + (modelData.remark || "-")
                                    color: appTheme.textMuted
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    MbStatusChip { appTheme: page.appTheme; label: "开始"; value: page.compactTime(modelData.start_time || modelData.created_at); type: "neutral"; Layout.preferredWidth: 210 }
                                    MbStatusChip { appTheme: page.appTheme; label: "结束"; value: page.compactTime(modelData.end_time); type: modelData.end_time ? "neutral" : "warning"; Layout.preferredWidth: 210 }
                                    MbStatusChip { appTheme: page.appTheme; label: "调用"; value: String(modelData.call_count || 0); type: "primary"; Layout.preferredWidth: 96 }
                                    MbStatusChip { appTheme: page.appTheme; label: "接口"; value: String(modelData.interface_count || 0); type: "neutral"; Layout.preferredWidth: 96 }
                                    MbStatusChip { appTheme: page.appTheme; label: "异常"; value: String(modelData.exception_count || 0); type: (modelData.exception_count || 0) > 0 ? "danger" : "neutral"; Layout.preferredWidth: 96 }
                                }
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 106
                                spacing: 8

                                MbButton {
                                    appTheme: page.appTheme
                                    text: modelData.id === activeSessionId ? "当前" : "打开会话"
                                    variant: "primary"
                                    enabled: modelData.id !== activeSessionId
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    onClicked: bridge.selectSession(modelData.id)
                                }

                                MbButton {
                                    appTheme: page.appTheme
                                    text: "删除会话"
                                    variant: "danger"
                                    enabled: page.canClearSessions
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    onClicked: bridge.deleteSession(modelData.id)
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
                        text: "暂无历史会话"
                        color: appTheme.textStrong
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "点击“新建 Session”后开始调试"
                        color: appTheme.textMuted
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
