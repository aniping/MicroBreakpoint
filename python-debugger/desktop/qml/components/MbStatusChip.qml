import QtQuick
import QtQuick.Layouts

Rectangle {
    id: chip

    property var appTheme
    property string label: ""
    property string value: ""
    property string type: "neutral"

    implicitWidth: Math.max(116, content.implicitWidth + 22)
    implicitHeight: 32
    radius: 5
    color: softColor()
    border.color: borderColor()

    function borderColor() {
        if (type === "primary") return appTheme.primary
        if (type === "success") return appTheme.success
        if (type === "warning") return appTheme.warning
        if (type === "danger") return appTheme.danger
        return appTheme.border
    }

    function softColor() {
        if (type === "primary") return appTheme.primarySoft
        if (type === "success") return appTheme.successSoft
        if (type === "warning") return appTheme.warningSoft
        if (type === "danger") return appTheme.dangerSoft
        return appTheme.panelBg
    }

    function valueColor() {
        if (type === "neutral") return appTheme.textNormal
        return borderColor()
    }

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8

        Text {
            text: chip.label
            color: chip.appTheme.textMuted
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: chip.value
            color: chip.valueColor()
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
