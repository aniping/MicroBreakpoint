import QtQuick
import QtQuick.Controls

TextField {
    id: field

    property var appTheme

    implicitHeight: 38
    color: appTheme.textStrong
    placeholderTextColor: appTheme.textMuted
    selectedTextColor: appTheme.onAccent
    selectionColor: appTheme.primary
    font.pixelSize: 14
    selectByMouse: true
    leftPadding: 12
    rightPadding: 12
    verticalAlignment: TextInput.AlignVCenter

    background: Rectangle {
        radius: 5
        color: field.appTheme.inputBg
        border.color: field.activeFocus ? field.appTheme.inputFocus : field.appTheme.inputBorder
    }
}
