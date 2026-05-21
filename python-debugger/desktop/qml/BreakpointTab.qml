import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property var items: []
    property color panel: "#141a21"
    property color border: "#2a333d"
    property color textStrong: "#e8eef5"
    property color textNormal: "#c7d0da"
    property color textMuted: "#8b98a7"
    property color green: "#55d66b"
    property color red: "#ff5d5d"

    component MiniSwitch: Rectangle {
        id: sw
        property bool checked: false
        signal toggled(bool checked)
        width: 44
        height: 22
        radius: 11
        color: checked ? "#1f6feb" : "#26313d"
        border.color: checked ? "#58a6ff" : "#4b5563"
        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: "#e8eef5"
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? 24 : 4
            Behavior on x { NumberAnimation { duration: 110 } }
        }
        MouseArea { anchors.fill: parent; onClicked: sw.toggled(!sw.checked) }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: panel
        border.color: border
        radius: 3

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                color: panel
                border.color: border
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 16; text: "断点管理"; color: textStrong; font.pixelSize: 16; font.weight: Font.DemiBold }
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 16; text: "共 " + items.length + " 个"; color: textMuted; font.pixelSize: 14 }
            }
            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: items
                clip: true
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: 70
                    color: index % 2 ? "#151c24" : "#111820"
                    border.color: border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 14
                        Rectangle { width: 10; height: 10; radius: 5; color: modelData.enabled ? green : red }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: modelData.name || modelData.method_name; color: textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: (modelData.method_name || "-") + " | 条件 " + JSON.stringify(modelData.condition || {}) + " | 命中 " + (modelData.hit_count || 0) + " 次"; color: textMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                        Text { text: modelData.enabled ? "启用" : "禁用"; color: modelData.enabled ? green : red; font.pixelSize: 14; font.weight: Font.DemiBold }
                        MiniSwitch {
                            checked: !!modelData.enabled
                            onToggled: function(value) { bridge.setBreakpointEnabled(modelData.id, value) }
                        }
                        Button {
                            text: "删除"
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 32
                            onClicked: bridge.deleteBreakpoint(modelData.id)
                            background: Rectangle { radius: 4; color: parent.hovered ? "#5a1f2a" : "#2b1720"; border.color: "#7f2d3a" }
                            contentItem: Text { text: parent.text; color: "#ffb4b4"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }
            }
        }
    }
}
