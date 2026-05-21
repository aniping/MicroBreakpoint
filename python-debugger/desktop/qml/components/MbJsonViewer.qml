import QtQuick
import QtQuick.Controls

Rectangle {
    id: viewer

    property var appTheme
    property alias text: jsonText.text

    color: appTheme.codeBg
    border.color: appTheme.border
    radius: 5

    ScrollView {
        anchors.fill: parent
        anchors.margins: 8
        clip: true

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitWidth: 8
                radius: 4
                color: parent.pressed ? viewer.appTheme.primary : viewer.appTheme.textDisabled
            }
            background: Rectangle { color: "transparent" }
        }

        ScrollBar.horizontal: ScrollBar {
            policy: ScrollBar.AsNeeded
            contentItem: Rectangle {
                implicitHeight: 8
                radius: 4
                color: parent.pressed ? viewer.appTheme.primary : viewer.appTheme.textDisabled
            }
            background: Rectangle { color: "transparent" }
        }

        TextArea {
            id: jsonText
            readOnly: true
            selectByMouse: true
            color: viewer.appTheme.codeText
            selectedTextColor: viewer.appTheme.onAccent
            selectionColor: viewer.appTheme.primary
            font.family: "Consolas"
            font.pixelSize: 13
            wrapMode: TextArea.NoWrap
            background: Rectangle { color: "transparent" }
        }
    }
}
