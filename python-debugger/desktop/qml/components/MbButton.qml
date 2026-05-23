import QtQuick
import QtQuick.Controls

Button {
    id: control

    property var appTheme
    property string variant: "neutral"
    property string iconText: ""

    implicitWidth: Math.max(92, contentRow.implicitWidth + 26)
    implicitHeight: 36
    padding: 0
    font.pixelSize: 13
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
        if (variant === "ghost") return hovered ? appTheme.panelHover : "transparent"
        if (pressed) return appTheme.panelActive
        if (hovered) return appTheme.panelHover
        if (variant === "primary") return appTheme.primarySoft
        if (variant === "success") return appTheme.successSoft
        if (variant === "warning") return appTheme.warningSoft
        if (variant === "danger") return appTheme.dangerSoft
        return appTheme.inputBg
    }

    function foregroundColor() {
        if (!enabled) return appTheme.textDisabled
        if (variant === "primary") return appTheme.primary
        if (variant === "success") return appTheme.success
        if (variant === "warning") return appTheme.warning
        if (variant === "danger") return appTheme.danger
        return appTheme.textStrong
    }

    function borderColor() {
        if (!enabled) return appTheme.borderSoft
        if (variant === "ghost") return "transparent"
        if (variant === "primary" || variant === "success" || variant === "warning" || variant === "danger") return accentColor()
        return appTheme.border
    }

    contentItem: Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: control.iconText.length > 0 ? 8 : 0

        Text {
            visible: control.iconText.length > 0
            text: control.iconText
            color: control.foregroundColor()
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            text: control.text
            color: control.foregroundColor()
            font: control.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    background: Rectangle {
        radius: 4
        color: control.backgroundColor()
        border.color: control.borderColor()
        border.width: control.variant === "neutral" ? 1 : 1
    }
}
