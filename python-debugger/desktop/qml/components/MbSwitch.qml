import QtQuick

Rectangle {
    id: control

    property var appTheme
    property bool checked: false
    property bool enabledSwitch: true

    signal toggled(bool checked)

    width: 42
    height: 22
    radius: 11
    color: checked ? appTheme.primary : appTheme.panelBgAlt
    border.color: checked ? appTheme.primaryHover : appTheme.inputBorder
    opacity: enabledSwitch ? 1 : 0.45

    Rectangle {
        width: 16
        height: 16
        radius: 8
        color: control.checked ? "#FFFFFF" : control.appTheme.textMuted
        anchors.verticalCenter: parent.verticalCenter
        x: control.checked ? 22 : 4

        Behavior on x { NumberAnimation { duration: 110 } }
    }

    MouseArea {
        anchors.fill: parent
        enabled: control.enabledSwitch
        onClicked: control.toggled(!control.checked)
    }
}
