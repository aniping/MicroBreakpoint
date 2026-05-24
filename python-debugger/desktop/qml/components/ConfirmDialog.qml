import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Popup {
    id: dialog

    property var appTheme
    property string title: "确认操作"
    property string message: ""
    property string confirmText: "确认"
    property string confirmVariant: "danger"
    property var confirmAction: null

    function ask(titleText, messageText, confirmTextValue, action) {
        title = titleText
        message = messageText
        confirmText = confirmTextValue || "确认"
        confirmAction = action
        open()
    }

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape
    padding: 0
    width: Math.min(440, parent ? parent.width - 32 : 440)
    x: parent ? Math.round((parent.width - width) / 2) : 0
    y: parent ? Math.round((parent.height - height) / 2) : 0

    background: Rectangle {
        radius: 6
        color: dialog.appTheme.panelBg
        border.color: dialog.appTheme.border
    }

    contentItem: ColumnLayout {
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            radius: 6
            color: dialog.appTheme.panelBg
            border.color: dialog.appTheme.borderSoft

            Text {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                text: dialog.title
                color: dialog.appTheme.textStrong
                font.pixelSize: 17
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.margins: 18
            text: dialog.message
            color: dialog.appTheme.textNormal
            font.pixelSize: 14
            lineHeight: 1.25
            wrapMode: Text.Wrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            Layout.rightMargin: 18
            Layout.bottomMargin: 18
            spacing: 10

            Item { Layout.fillWidth: true }

            MbButton {
                appTheme: dialog.appTheme
                text: "取消"
                variant: "neutral"
                Layout.preferredWidth: 92
                Layout.preferredHeight: 36
                onClicked: dialog.close()
            }

            MbButton {
                appTheme: dialog.appTheme
                text: dialog.confirmText
                iconText: "!"
                variant: dialog.confirmVariant
                Layout.preferredWidth: 112
                Layout.preferredHeight: 36
                onClicked: {
                    var action = dialog.confirmAction
                    dialog.close()
                    dialog.confirmAction = null
                    if (action) action()
                }
            }
        }
    }

    onClosed: confirmAction = null
}
