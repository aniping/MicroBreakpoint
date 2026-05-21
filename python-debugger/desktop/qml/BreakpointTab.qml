import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property var items: []

    ListView {
        id: list
        anchors.fill: parent
        anchors.margins: 12
        model: items
        clip: true
        delegate: Rectangle {
            required property var modelData
            width: list.width
            height: 72
            color: index % 2 ? "#f8fafc" : "#ffffff"
            border.color: "#d9e2ec"
            Column {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 4
                Text { text: (modelData.enabled ? "启用" : "禁用") + "  " + modelData.name; font.bold: true }
                Text { text: modelData.method_name + " | 条件 " + JSON.stringify(modelData.condition || {}) + " | 命中 " + modelData.hit_count + " 次"; color: "#475569" }
            }
        }
    }
}
