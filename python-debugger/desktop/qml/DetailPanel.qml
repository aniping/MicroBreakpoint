import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: detailPanel
    property var appTheme
    property string title: "详情"
    property string text: ""
    color: appTheme.panelBg
    border.color: appTheme.border
    radius: 3

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            color: appTheme.panelBg
            border.color: appTheme.border
            Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: title; color: appTheme.textStrong; font.bold: true; font.pixelSize: 15 }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitWidth: 8; radius: 4; color: parent.pressed ? detailPanel.appTheme.primary : detailPanel.appTheme.textDisabled }
                background: Rectangle { color: detailPanel.appTheme.panelBgAlt; radius: 4 }
            }
            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { implicitHeight: 8; radius: 4; color: parent.pressed ? detailPanel.appTheme.primary : detailPanel.appTheme.textDisabled }
                background: Rectangle { color: detailPanel.appTheme.panelBgAlt; radius: 4 }
            }

            TextArea {
                readOnly: true
                selectByMouse: true
                text: detailPanel.text
                color: detailPanel.appTheme.codeText
                selectedTextColor: detailPanel.appTheme.onAccent
                selectionColor: detailPanel.appTheme.primary
                font.family: "Consolas"
                font.pixelSize: 13
                wrapMode: TextArea.NoWrap
                background: Rectangle { color: detailPanel.appTheme.codeBg; border.color: detailPanel.appTheme.border }
            }
        }
    }
}
