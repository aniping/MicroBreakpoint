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
                height: 72
                color: modelData.status === "paused" ? "#fff4cc" : (index % 2 ? "#f8fafc" : "#ffffff")
                border.color: "#d9e2ec"
                Column {
                    anchors.fill: parent
                    anchors.margins: 8
                    spacing: 4
                    Text { text: "#" + modelData.call_index + "  " + modelData.service_name + "  " + modelData.method_name + "  " + modelData.status; font.bold: true }
                    Text { text: modelData.display_name + " | " + modelData.thread_name + " | " + (modelData.cost_ms || "-") + "ms"; color: "#475569" }
                    Row {
                        spacing: 8
                        Button { text: "继续执行"; enabled: modelData.status === "paused"; onClicked: bridge.continueCall(modelData.call_id) }
                        Button { text: "按参数建断点"; onClicked: bridge.createBreakpointFromCall(modelData.call_id) }
                    }
                }
            }
        }

        DetailPanel {
            Layout.preferredWidth: 380
            Layout.fillHeight: true
            title: "调用详情"
            text: list.currentItem ? JSON.stringify(list.currentItem.modelData, null, 2) : "选择一条调用记录"
        }
    }
}
