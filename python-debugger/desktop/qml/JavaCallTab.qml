import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page

    property var appTheme
    property string resultText: ""
    property color panel: appTheme.panelBg
    property color border: appTheme.border
    property color textStrong: appTheme.textStrong
    property color textNormal: appTheme.textNormal
    property color textMuted: appTheme.textMuted

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            color: panel
            border.color: border
            radius: 3
            RowLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                Text { text: "Java 服务地址"; color: textNormal; font.pixelSize: 15 }
                MbTextField { id: baseUrl; appTheme: page.appTheme; Layout.fillWidth: true; text: "http://127.0.0.1:8080" }
                MbButton { appTheme: page.appTheme; text: "测试连接"; variant: "primary"; Layout.preferredWidth: 110; onClicked: bridge.javaPing(baseUrl.text) }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 146
            color: panel
            border.color: border
            radius: 3
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14
                Text { text: "预设调用"; color: textStrong; font.pixelSize: 16; font.weight: Font.DemiBold }
                RowLayout {
                    spacing: 10
                    MbButton { appTheme: page.appTheme; text: "initialize"; variant: "primary"; Layout.preferredWidth: 128; onClicked: bridge.javaInitialize(baseUrl.text) }
                    MbButton { appTheme: page.appTheme; text: "control-create"; variant: "primary"; Layout.preferredWidth: 148; onClicked: bridge.javaControlCreate(baseUrl.text) }
                    MbButton { appTheme: page.appTheme; text: "control-start"; variant: "primary"; Layout.preferredWidth: 138; onClicked: bridge.javaControlStart(baseUrl.text) }
                    MbButton { appTheme: page.appTheme; text: "control-stop"; variant: "primary"; Layout.preferredWidth: 138; onClicked: bridge.javaControlStop(baseUrl.text) }
                    MbButton { appTheme: page.appTheme; text: "error"; variant: "danger"; Layout.preferredWidth: 108; onClicked: bridge.javaError(baseUrl.text) }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    spacing: 10
                    MbTextField { id: instType; appTheme: page.appTheme; Layout.preferredWidth: 150; placeholderText: "instType"; text: "VNA" }
                    MbTextField { id: cmdName; appTheme: page.appTheme; Layout.preferredWidth: 180; placeholderText: "cmdName"; text: "create" }
                    SpinBox {
                        id: slotId
                        from: 1
                        to: 64
                        value: 1
                        Layout.preferredWidth: 110
                        background: Rectangle { radius: 5; color: page.appTheme.inputBg; border.color: page.appTheme.inputBorder }
                        contentItem: TextInput { text: slotId.textFromValue(slotId.value, slotId.locale); color: textStrong; horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter; readOnly: true }
                    }
                    MbButton { appTheme: page.appTheme; text: "自定义调用"; variant: "primary"; Layout.preferredWidth: 128; onClicked: bridge.javaControl(baseUrl.text, instType.text, cmdName.text, slotId.value) }
                }
            }
        }

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
                    Layout.preferredHeight: 42
                    color: panel
                    border.color: border
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "调用结果"; color: textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
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
