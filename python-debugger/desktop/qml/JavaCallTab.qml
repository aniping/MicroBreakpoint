import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page

    property var appTheme
    property var stateData: ({mode: "idle", hasSession: false})
    property string resultText: ""
    property string connectionState: "unknown"

    function isCaptureActive() {
        return stateData && stateData.mode === "debug"
    }

    function captureHint() {
        if (isCaptureActive()) {
            return "调试中，Java 调用会进入断点判断流程"
        }
        if (stateData && stateData.hasSession) {
            return "请先点击“开始调试”，否则 Java 调用不会被记录"
        }
        return "请先新建会话并开始调试，否则 Java 调用不会被记录"
    }

    function connectionLabel() {
        if (connectionState === "connected") return "已连接"
        if (connectionState === "failed") return "未连接"
        if (connectionState === "checking") return "检测中"
        return "未检测"
    }

    function connectionType() {
        if (connectionState === "connected") return "success"
        if (connectionState === "failed") return "danger"
        if (connectionState === "checking") return "primary"
        return "neutral"
    }

    function normalizedSlotId() {
        var value = parseInt(slotId.text || "1")
        if (isNaN(value) || value < 1) return 1
        return value
    }

    onResultTextChanged: {
        if (connectionState === "checking") {
            try {
                var data = JSON.parse(resultText)
                connectionState = (data.success === true || data.text === "pong" || data.code === 0) ? "connected" : "failed"
            } catch (e) {
                connectionState = resultText.indexOf("pong") >= 0 ? "connected" : "failed"
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        MbPanel {
            appTheme: page.appTheme
            Layout.fillWidth: true
            Layout.preferredHeight: 112

            ColumnLayout {
                anchors.fill: parent
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "Java 服务连接"
                        color: appTheme.textStrong
                        font.pixelSize: 17
                        font.weight: Font.DemiBold
                    }

                    MbTag {
                        appTheme: page.appTheme
                        text: page.connectionLabel()
                        type: page.connectionType()
                    }

                    Item { Layout.fillWidth: true }
                }

                Text {
                    text: page.captureHint()
                    color: page.isCaptureActive() ? appTheme.success : appTheme.warning
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        text: "服务地址"
                        color: appTheme.textMuted
                        font.pixelSize: 13
                        Layout.preferredWidth: 66
                    }

                    MbTextField {
                        id: baseUrl
                        appTheme: page.appTheme
                        Layout.fillWidth: true
                        text: "http://127.0.0.1:8080"
                    }

                    MbButton {
                        appTheme: page.appTheme
                        text: "测试连接"
                        iconText: "●"
                        variant: "primary"
                        Layout.preferredWidth: 118
                        onClicked: {
                            page.connectionState = "checking"
                            bridge.javaPing(baseUrl.text)
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 214
            spacing: 12

            MbPanel {
                appTheme: page.appTheme
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    Text {
                        text: "初始化接口"
                        color: appTheme.textStrong
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "initialize 会触发 Demo Controller 到 Service 的一次调用"
                        color: appTheme.textMuted
                        font.pixelSize: 13
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }

                    MbButton {
                        appTheme: page.appTheme
                        text: "调用 initialize"
                        iconText: "▶"
                        variant: "primary"
                        Layout.fillWidth: true
                        onClicked: bridge.javaInitialize(baseUrl.text)
                    }
                }
            }

            MbPanel {
                appTheme: page.appTheme
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "控制接口"
                            color: appTheme.textStrong
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        MbTag { appTheme: page.appTheme; text: "control"; type: "primary" }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MbTextField { id: objectType; appTheme: page.appTheme; Layout.fillWidth: true; placeholderText: "仪表类型"; text: "VNA" }
                        MbTextField { id: cmdName; appTheme: page.appTheme; Layout.fillWidth: true; placeholderText: "cmdName"; text: "create" }
                        MbTextField { id: slotId; appTheme: page.appTheme; Layout.preferredWidth: 86; placeholderText: "slotId"; text: "1" }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MbButton { appTheme: page.appTheme; text: "create"; variant: "primary"; Layout.fillWidth: true; onClicked: bridge.javaControlCreate(baseUrl.text) }
                        MbButton { appTheme: page.appTheme; text: "start"; variant: "primary"; Layout.fillWidth: true; onClicked: bridge.javaControlStart(baseUrl.text) }
                        MbButton { appTheme: page.appTheme; text: "stop"; variant: "primary"; Layout.fillWidth: true; onClicked: bridge.javaControlStop(baseUrl.text) }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        MbButton {
                            appTheme: page.appTheme
                            text: "调用 control"
                            iconText: "▶"
                            variant: "primary"
                            Layout.fillWidth: true
                            onClicked: bridge.javaControl(baseUrl.text, objectType.text, cmdName.text, page.normalizedSlotId())
                        }

                        MbButton {
                            appTheme: page.appTheme
                            text: "异常测试"
                            iconText: "!"
                            variant: "danger"
                            Layout.preferredWidth: 128
                            onClicked: bridge.javaError(baseUrl.text)
                        }
                    }
                }
            }
        }

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
                    Layout.preferredHeight: 48
                    color: appTheme.panelBg
                    border.color: appTheme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10

                        Text {
                            text: "调用结果"
                            color: appTheme.textStrong
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        MbTag {
                            appTheme: page.appTheme
                            text: resultText.length > 0 ? "已返回" : "等待调用"
                            type: resultText.length > 0 ? "success" : "neutral"
                        }
                    }
                }

                MbJsonViewer {
                    appTheme: page.appTheme
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: resultText
                }
            }
        }
    }
}
