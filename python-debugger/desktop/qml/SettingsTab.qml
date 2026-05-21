import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "#141a21"
        border.color: "#2a333d"
        radius: 3

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 14

            Text {
                text: "设置"
                color: "#e8eef5"
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                color: "#10161d"
                border.color: "#2a333d"
                radius: 4
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    Text { text: "后端地址"; color: "#c7d0da"; font.pixelSize: 14 }
                    Text { text: "http://127.0.0.1:5050"; color: "#8b98a7"; font.pixelSize: 13 }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 92
                color: "#10161d"
                border.color: "#2a333d"
                radius: 4
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 8
                    Text { text: "使用流程"; color: "#c7d0da"; font.pixelSize: 14 }
                    Text { text: "新建会话 -> 开始记录 -> Java 调用 -> 停止记录 -> 设置断点 -> 开始调试"; color: "#8b98a7"; font.pixelSize: 13 }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
