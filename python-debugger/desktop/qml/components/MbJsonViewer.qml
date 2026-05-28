import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: viewer

    property var appTheme
    property alias text: jsonText.text

    color: appTheme.panelBg
    border.color: appTheme.border
    radius: 6

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            radius: 6
            color: viewer.appTheme.panelBgAlt
            border.color: viewer.appTheme.borderSoft
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 8
                Text {
                    text: "JSON"
                    color: viewer.appTheme.textStrong
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text {
                    text: jsonText.text.length + " 字符"
                    color: viewer.appTheme.textMuted
                    font.pixelSize: 11
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: viewer.appTheme.codeBg
            border.color: viewer.appTheme.borderSoft
            radius: 6
            Layout.margins: 8

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
                    font.pixelSize: 12
                    wrapMode: TextEdit.Wrap
                    leftPadding: 4
                    rightPadding: 12
                    topPadding: 4
                    bottomPadding: 4
                    background: Rectangle { color: "transparent" }
                }
            }
        }
    }
}
