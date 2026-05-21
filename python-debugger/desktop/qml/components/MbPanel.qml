import QtQuick

Rectangle {
    id: panel

    property var appTheme
    property int padding: 12
    default property alias content: contentItem.data

    color: appTheme.panelBg
    border.color: appTheme.border
    radius: 6

    Item {
        id: contentItem
        anchors.fill: parent
        anchors.margins: panel.padding
    }
}
