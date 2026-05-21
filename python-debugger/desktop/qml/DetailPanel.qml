import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Frame {
    property string title: "详情"
    property string text: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        Label { text: title; font.bold: true; font.pixelSize: 16 }
        TextArea {
            Layout.fillWidth: true
            Layout.fillHeight: true
            readOnly: true
            text: parent.parent.text
            font.family: "Consolas"
            wrapMode: TextArea.Wrap
        }
    }
}
