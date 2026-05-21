import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property var items: []

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: items
            clip: true
            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: 76
                color: index % 2 ? "#f8fafc" : "#ffffff"
                border.color: "#d9e2ec"
                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    Text { text: modelData.method_name + "  " + modelData.display_name; font.bold: true }
                    Text { text: modelData.class_name + " | 调用 " + modelData.call_count + " 次 | 异常 " + modelData.exception_count + " 次"; color: "#475569" }
                    Button { text: "对此接口设置断点"; onClicked: bridge.createBreakpointFromInterface(modelData.id) }
                }
            }
        }

        DetailPanel {
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            title: "接口详情"
            text: list.currentItem ? JSON.stringify(list.currentItem.modelData, null, 2) : "选择一个接口"
        }
    }
}
