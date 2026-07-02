import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page

    property var appTheme
    property string themeMode: "dark"
    property string backendUrl: ""
    property var settingsData: ({themeMode: "dark", server: {host: "127.0.0.1"}, debugTarget: {host: "127.0.0.1", port: 8080, debuggerSwitchPath: "/api/demo/debugger/enabled", requestTimeoutMs: 1000}})
    property bool loading: false

    signal themeModeRequested(string mode)
    signal settingsSaveRequested(string payload)

    function themeLabel() {
        return themeMode === "light" ? "亮色模式" : "暗色模式"
    }

    function target() {
        return settingsData && settingsData.debugTarget ? settingsData.debugTarget : {}
    }

    function server() {
        return settingsData && settingsData.server ? settingsData.server : {host: "127.0.0.1"}
    }

    function loadFields() {
        loading = true
        var data = target()
        hostField.text = data.host || "127.0.0.1"
        portField.text = String(data.port || 8080)
        switchPathField.text = data.debuggerSwitchPath || "/api/demo/debugger/enabled"
        timeoutField.text = String(data.requestTimeoutMs || 1000)
        loading = false
    }

    function scheduleSave() {
        if (!loading) saveTimer.restart()
    }

    function commitFields() {
        if (loading) return
        var next = {
            themeMode: page.themeMode,
            server: {
                host: page.server().host || "127.0.0.1"
            },
            debugTarget: {
                host: hostField.text.trim(),
                port: portField.text.length > 0 ? Number(portField.text) : 8080,
                debuggerSwitchPath: switchPathField.text.trim(),
                requestTimeoutMs: timeoutField.text.length > 0 ? Number(timeoutField.text) : 1000
            }
        }
        settingsSaveRequested(JSON.stringify(next))
    }

    onSettingsDataChanged: loadFields()
    Component.onCompleted: loadFields()

    Timer {
        id: saveTimer
        interval: 450
        repeat: false
        onTriggered: page.commitFields()
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "设置"
                            color: appTheme.textStrong
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "当前外观: " + page.themeLabel()
                            color: appTheme.textMuted
                            font.pixelSize: 13
                        }
                    }

                    MbTag {
                        appTheme: page.appTheme
                        text: "自动保存"
                        type: "success"
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 14

                MbPanel {
                    appTheme: page.appTheme
                    Layout.fillWidth: true
                    Layout.preferredHeight: 160

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "外观"
                                color: appTheme.textStrong
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                            MbTag {
                                appTheme: page.appTheme
                                text: page.themeLabel()
                                type: themeMode === "light" ? "primary" : "neutral"
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 12

                            ThemeChoice {
                                appTheme: page.appTheme
                                title: "暗色模式"
                                mark: "☾"
                                selected: page.themeMode === "dark"
                                onClicked: page.themeModeRequested("dark")
                            }

                            ThemeChoice {
                                appTheme: page.appTheme
                                title: "亮色模式"
                                mark: "☀"
                                selected: page.themeMode === "light"
                                onClicked: page.themeModeRequested("light")
                            }
                        }
                    }
                }

                MbPanel {
                    appTheme: page.appTheme
                    Layout.fillWidth: true
                    Layout.preferredHeight: 246

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: "业务服务调试开关"
                                color: appTheme.textStrong
                                font.pixelSize: 16
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                            MbTag {
                                appTheme: page.appTheme
                                text: "POST"
                                type: "primary"
                            }
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            columnSpacing: 14
                            rowSpacing: 10

                            FieldLabel { appTheme: page.appTheme; text: "服务 IP / Host" }
                            MbTextField {
                                id: hostField
                                appTheme: page.appTheme
                                Layout.fillWidth: true
                                placeholderText: "127.0.0.1"
                                onTextEdited: page.scheduleSave()
                                onEditingFinished: page.commitFields()
                            }

                            FieldLabel { appTheme: page.appTheme; text: "端口" }
                            MbTextField {
                                id: portField
                                appTheme: page.appTheme
                                Layout.fillWidth: true
                                placeholderText: "8080"
                                validator: IntValidator { bottom: 1; top: 65535 }
                                inputMethodHints: Qt.ImhDigitsOnly
                                onTextEdited: page.scheduleSave()
                                onEditingFinished: page.commitFields()
                            }

                            FieldLabel { appTheme: page.appTheme; text: "断点启用接口" }
                            MbTextField {
                                id: switchPathField
                                appTheme: page.appTheme
                                Layout.fillWidth: true
                                placeholderText: "/api/demo/debugger/enabled"
                                onTextEdited: page.scheduleSave()
                                onEditingFinished: page.commitFields()
                            }

                            FieldLabel { appTheme: page.appTheme; text: "请求超时(ms)" }
                            MbTextField {
                                id: timeoutField
                                appTheme: page.appTheme
                                Layout.fillWidth: true
                                placeholderText: "1000"
                                validator: IntValidator { bottom: 1; top: 600000 }
                                inputMethodHints: Qt.ImhDigitsOnly
                                onTextEdited: page.scheduleSave()
                                onEditingFinished: page.commitFields()
                            }
                        }
                    }
                }

                MbPanel {
                    appTheme: page.appTheme
                    Layout.fillWidth: true
                    Layout.preferredHeight: 92

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8
                        Text { text: "断点后端地址"; color: appTheme.textStrong; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: page.backendUrl; color: appTheme.textMuted; font.pixelSize: 13 }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    component FieldLabel: Text {
        property var appTheme
        color: appTheme.textMuted
        font.pixelSize: 13
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
        Layout.preferredWidth: 118
    }

    component ThemeChoice: Rectangle {
        id: choice
        property var appTheme
        property string title: ""
        property string mark: ""
        property bool selected: false
        signal clicked()

        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: 6
        color: selected ? appTheme.panelActive : appTheme.panelBgAlt
        border.color: selected ? appTheme.primary : appTheme.border

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Text {
                text: choice.mark
                color: choice.selected ? appTheme.primary : appTheme.textMuted
                font.pixelSize: 20
                Layout.preferredWidth: 30
            }

            Text {
                text: choice.title
                color: appTheme.textStrong
                font.pixelSize: 15
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            MbTag {
                visible: choice.selected
                appTheme: choice.appTheme
                text: "已启用"
                type: "primary"
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: choice.clicked()
        }
    }
}
