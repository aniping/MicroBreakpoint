import QtQuick
import QtQuick.Controls

Button {
    id: control

    property var appTheme
    property string variant: "neutral"
    property string iconText: ""

    implicitWidth: Math.max(96, contentRow.implicitWidth + 30)
    implicitHeight: 40
    padding: 0
    font.pixelSize: 14
    font.weight: Font.DemiBold

    function accentColor() {
        if (variant === "primary") return appTheme.primary
        if (variant === "success") return appTheme.success
        if (variant === "warning") return appTheme.warning
        if (variant === "danger") return appTheme.danger
        if (variant === "ghost") return appTheme.textMuted
        return appTheme.textMuted
    }

    function backgroundColor() {
        if (!enabled) return appTheme.panelBgAlt
        if (pressed) return variant === "ghost" ? appTheme.panelHover : accentColor()
        if (hovered) return variant === "ghost" ? appTheme.panelHover : appTheme.primarySoft
        if (variant === "ghost") return "transparent"
        return appTheme.panelBgAlt
    }

    contentItem: Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: control.iconText.length > 0 ? 8 : 0

        Text {
            visible: control.iconText.length > 0
            text: control.iconText
            color: control.enabled ? control.accentColor() : control.appTheme.textDisabled
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: control.text
            color: control.enabled ? control.appTheme.textStrong : control.appTheme.textDisabled
            font: control.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    background: Rectangle {
        radius: 5
        color: control.backgroundColor()
        border.color: control.enabled ? (control.variant === "ghost" ? "transparent" : control.appTheme.border) : control.appTheme.borderSoft
    }
}
