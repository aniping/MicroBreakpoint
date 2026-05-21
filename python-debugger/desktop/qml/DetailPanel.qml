import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: detailPanel
    property string title: "详情"
    property string text: ""
    color: "#141a21"
    border.color: "#2a333d"
    radius: 3

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            color: "#141a21"
            border.color: "#2a333d"
            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: title; color: "#e8eef5"; font.bold: true; font.pixelSize: 15 }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 8; radius: 4; color: parent.pressed ? "#2f81f7" : "#4b5563" }
                background: Rectangle { color: "#0d1218"; radius: 4 }
            }
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitHeight: 8; radius: 4; color: parent.pressed ? "#2f81f7" : "#4b5563" }
                background: Rectangle { color: "#0d1218"; radius: 4 }
            }

            TextArea {
                readOnly: true
                selectByMouse: true
                text: detailPanel.text
                color: "#b6e3ff"
                selectedTextColor: "#ffffff"
                selectionColor: "#1f6feb"
                font.family: "Consolas"
                font.pixelSize: 13
                wrapMode: TextArea.NoWrap
                background: Rectangle { color: "#0f151c"; border.color: "#2a333d" }
            }
        }
    }
}
