import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property string resultText: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Label { text: "Java 服务地址" }
            TextField { id: baseUrl; Layout.fillWidth: true; text: "http://127.0.0.1:8080" }
            Button { text: "测试连接"; onClicked: bridge.javaPing(baseUrl.text) }
        }

        RowLayout {
            spacing: 8
            Button { text: "调用 initialize"; onClicked: bridge.javaInitialize(baseUrl.text) }
            Button { text: "调用 control-create"; onClicked: bridge.javaControlCreate(baseUrl.text) }
            Button { text: "调用 control-start"; onClicked: bridge.javaControlStart(baseUrl.text) }
            Button { text: "调用 control-stop"; onClicked: bridge.javaControlStop(baseUrl.text) }
            Button { text: "调用 error"; onClicked: bridge.javaError(baseUrl.text) }
        }

        GroupBox {
            title: "自定义调用"
            Layout.fillWidth: true
            RowLayout {
                anchors.fill: parent
                TextField { id: instType; placeholderText: "instType"; text: "VNA" }
                TextField { id: cmdName; placeholderText: "cmdName"; text: "create" }
                SpinBox { id: slotId; from: 1; to: 64; value: 1 }
                Button { text: "自定义调用"; onClicked: bridge.javaControl(baseUrl.text, instType.text, cmdName.text, slotId.value) }
            }
        }

        TextArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            readOnly: true
            text: resultText
            font.family: "Consolas"
        }
    }
}
