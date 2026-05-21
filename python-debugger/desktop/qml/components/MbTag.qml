import QtQuick

Rectangle {
    id: tag

    property var appTheme
    property string text: ""
    property string type: "neutral"

    implicitWidth: Math.max(64, label.implicitWidth + 18)
    implicitHeight: 26
    radius: 5
    color: softColor()
    border.color: accentColor()

    function accentColor() {
        if (type === "primary") return appTheme.primary
        if (type === "success") return appTheme.success
        if (type === "warning") return appTheme.warning
        if (type === "danger") return appTheme.danger
        return appTheme.textMuted
    }

    function softColor() {
        if (type === "primary") return appTheme.primarySoft
        if (type === "success") return appTheme.successSoft
        if (type === "warning") return appTheme.warningSoft
        if (type === "danger") return appTheme.dangerSoft
        return appTheme.panelBgAlt
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: tag.text
        color: tag.accentColor()
        font.pixelSize: 12
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        maximumLineCount: 1
    }
}
