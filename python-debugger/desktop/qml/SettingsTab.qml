import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page

    property var appTheme
    property string themeMode: "dark"

    signal themeModeRequested(string mode)

    function themeLabel() {
        return themeMode === "light" ? "亮色模式" : "暗色模式"
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
                        text: page.themeLabel()
                        type: themeMode === "light" ? "primary" : "neutral"
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
                    Layout.preferredHeight: 178

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
                                text: "自动保存"
                                type: "success"
                            }
                        }

                        Text {
                            text: "选择后立即生效，重启后保持。"
                            color: appTheme.textMuted
                            font.pixelSize: 13
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 12

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: themeMode === "dark" ? appTheme.panelActive : appTheme.panelBgAlt
                                border.color: themeMode === "dark" ? appTheme.primary : appTheme.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    Text {
                                        text: "☀"
                                        color: appTheme.textMuted
                                        font.pixelSize: 20
                                        Layout.preferredWidth: 30
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text { text: "暗色模式"; color: appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                                        Text { text: "适合长时间调试和低光环境"; color: appTheme.textMuted; font.pixelSize: 12 }
                                    }

                                    MbTag {
                                        visible: themeMode === "dark"
                                        appTheme: page.appTheme
                                        text: "已启用"
                                        type: "primary"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: page.themeModeRequested("dark")
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 6
                                color: themeMode === "light" ? appTheme.panelActive : appTheme.panelBgAlt
                                border.color: themeMode === "light" ? appTheme.primary : appTheme.border

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 14
                                    spacing: 12

                                    Text {
                                        text: "☾"
                                        color: appTheme.primary
                                        font.pixelSize: 22
                                        Layout.preferredWidth: 30
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text { text: "亮色模式"; color: appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                                        Text { text: "适合演示、评审和明亮环境"; color: appTheme.textMuted; font.pixelSize: 12 }
                                    }

                                    MbTag {
                                        visible: themeMode === "light"
                                        appTheme: page.appTheme
                                        text: "已启用"
                                        type: "primary"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: page.themeModeRequested("light")
                                }
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
                        Text { text: "后端地址"; color: appTheme.textStrong; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text { text: "http://127.0.0.1:5050"; color: appTheme.textMuted; font.pixelSize: 13 }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
