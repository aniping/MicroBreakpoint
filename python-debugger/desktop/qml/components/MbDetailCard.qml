import QtQuick
import QtQuick.Layouts

Rectangle {
    id: card

    property var appTheme
    property string title: ""
    property var rows: []
    property int labelWidth: 104

    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 24
    radius: 5
    color: appTheme.panelBgAlt
    border.color: appTheme.borderSoft

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            visible: card.title.length > 0
            text: card.title
            color: card.appTheme.textStrong
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.fillWidth: true
            elide: Text.ElideRight
        }

        Repeater {
            model: card.rows || []
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: String(modelData[0])
                    color: card.appTheme.textNormal
                    font.pixelSize: 13
                    Layout.preferredWidth: card.labelWidth
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }

                Text {
                    text: String(modelData[1])
                    color: card.appTheme.textStrong
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
            }
        }
    }
}
