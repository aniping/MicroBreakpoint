import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control

    property var appTheme
    property bool selected: false
    property string iconText: ""

    Layout.fillWidth: true
    implicitHeight: 52
    padding: 0

    background: Rectangle {
        radius: 0
        color: control.selected ? control.appTheme.panelActive : (control.hovered ? control.appTheme.panelHover : "transparent")
        border.color: control.selected ? control.appTheme.primary : "transparent"

        Rectangle {
            width: 3
            height: parent.height
            visible: control.selected
            color: control.appTheme.primary
            anchors.left: parent.left
        }
    }

    contentItem: Item {
        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.right: parent.right
            anchors.rightMargin: 12
            spacing: 12

            Text {
                text: control.iconText
                color: control.selected ? control.appTheme.primary : control.appTheme.textMuted
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                width: 20
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: control.text
                color: control.selected ? control.appTheme.textStrong : control.appTheme.textNormal
                font.pixelSize: 15
                font.weight: control.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
