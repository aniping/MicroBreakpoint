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
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            ScrollBar.horizontal.policy: ScrollBar.AsNeeded

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
