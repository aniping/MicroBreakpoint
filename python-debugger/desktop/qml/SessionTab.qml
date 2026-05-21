import QtQuick
import QtQuick.Controls

Item {
    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "#141a21"
        border.color: "#2a333d"
        radius: 3
        Text {
            anchors.centerIn: parent
            text: "历史会话"
            color: "#e8eef5"
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
    }
}
