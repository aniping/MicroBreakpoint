import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property var items: []
    property var selectedItem: items.length > 0 ? items[Math.max(0, list.currentIndex)] : null
    property color panel: "#141a21"
    property color border: "#2a333d"
    property color textStrong: "#e8eef5"
    property color textNormal: "#c7d0da"
    property color textMuted: "#8b98a7"
    property color blue: "#2f81f7"

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
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
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 16; text: "已发现接口"; color: textStrong; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 16; text: "共 " + items.length + " 个"; color: textMuted; font.pixelSize: 14 }
                }
                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: items
                    clip: true
                    currentIndex: items.length > 0 ? Math.max(0, currentIndex) : -1
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: list.width
                        height: 76
                        color: list.currentIndex === index ? "#173052" : (index % 2 ? "#151c24" : "#111820")
                        border.color: border
                        MouseArea { anchors.fill: parent; onClicked: list.currentIndex = index }
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12
                            Rectangle { width: 10; height: 36; radius: 2; color: blue }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { text: modelData.method_name + "  " + (modelData.display_name || ""); color: textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                Text { text: modelData.class_name || "-"; color: textMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                            Text { text: "调用 " + (modelData.call_count || 0); color: textNormal; font.pixelSize: 14 }
                            Text { text: "异常 " + (modelData.exception_count || 0); color: textMuted; font.pixelSize: 14 }
                            Button {
                                text: "设置断点"
                                Layout.preferredWidth: 96
                                Layout.preferredHeight: 34
                                onClicked: bridge.createBreakpointFromInterface(modelData.id)
                                background: Rectangle { radius: 4; color: parent.hovered ? "#1f5fb9" : "#1d4f96"; border.color: "#58a6ff" }
                                contentItem: Text { text: parent.text; color: "#ffffff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }
            }
        }

        DetailPanel {
            Layout.preferredWidth: 430
            Layout.fillHeight: true
            title: "接口详情"
            text: selectedItem ? JSON.stringify(selectedItem, null, 2) : "选择一个接口"
        }
    }
}
