import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property string resultText: ""
    property color panel: "#141a21"
    property color border: "#2a333d"
    property color textStrong: "#e8eef5"
    property color textNormal: "#c7d0da"
    property color textMuted: "#8b98a7"
    property color blue: "#2f81f7"

    component DarkButton: Button {
        implicitHeight: 38
        font.pixelSize: 14
        background: Rectangle { radius: 4; color: parent.hovered ? "#1f5fb9" : "#1d4f96"; border.color: "#58a6ff" }
        contentItem: Text { text: parent.text; color: "#ffffff"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    }

    component DarkField: TextField {
        color: textStrong
        placeholderTextColor: textMuted
        font.pixelSize: 14
        background: Rectangle { radius: 4; color: "#10161d"; border.color: border }
    }

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
                DarkField { id: baseUrl; Layout.fillWidth: true; text: "http://127.0.0.1:8080" }
                DarkButton { text: "测试连接"; Layout.preferredWidth: 110; onClicked: bridge.javaPing(baseUrl.text) }
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
                    DarkButton { text: "initialize"; Layout.preferredWidth: 128; onClicked: bridge.javaInitialize(baseUrl.text) }
                    DarkButton { text: "control-create"; Layout.preferredWidth: 148; onClicked: bridge.javaControlCreate(baseUrl.text) }
                    DarkButton { text: "control-start"; Layout.preferredWidth: 138; onClicked: bridge.javaControlStart(baseUrl.text) }
                    DarkButton { text: "control-stop"; Layout.preferredWidth: 138; onClicked: bridge.javaControlStop(baseUrl.text) }
                    DarkButton { text: "error"; Layout.preferredWidth: 108; onClicked: bridge.javaError(baseUrl.text) }
                    Item { Layout.fillWidth: true }
                }
                RowLayout {
                    spacing: 10
                    DarkField { id: instType; Layout.preferredWidth: 150; placeholderText: "instType"; text: "VNA" }
                    DarkField { id: cmdName; Layout.preferredWidth: 180; placeholderText: "cmdName"; text: "create" }
                    SpinBox {
                        id: slotId
                        from: 1
                        to: 64
                        value: 1
                        Layout.preferredWidth: 110
                        background: Rectangle { radius: 4; color: "#10161d"; border.color: border }
                        contentItem: TextInput { text: slotId.textFromValue(slotId.value, slotId.locale); color: textStrong; horizontalAlignment: Qt.AlignHCenter; verticalAlignment: Qt.AlignVCenter; readOnly: true }
                    }
                    DarkButton { text: "自定义调用"; Layout.preferredWidth: 128; onClicked: bridge.javaControl(baseUrl.text, instType.text, cmdName.text, slotId.value) }
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
                TextArea {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readOnly: true
                    text: resultText
                    color: "#b6e3ff"
                    selectedTextColor: "#ffffff"
                    selectionColor: "#1f6feb"
                    font.family: "Consolas"
                    font.pixelSize: 13
                    background: Rectangle { color: "#0f151c"; border.color: border }
                }
            }
        }
    }
}
