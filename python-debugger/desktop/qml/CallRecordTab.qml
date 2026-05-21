import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property var items: []
    property var breakpoints: []
    property bool canClearRecords: false
    property color bg: "#0d1218"
    property color panel: "#141a21"
    property color panel2: "#10161d"
    property color border: "#2a333d"
    property color textStrong: "#e8eef5"
    property color textNormal: "#c7d0da"
    property color textMuted: "#8b98a7"
    property color blue: "#2f81f7"
    property color green: "#55d66b"
    property color red: "#ff5d5d"
    property color amber: "#f4d13d"
    property string searchText: ""
    property int statusFilterIndex: 0
    property int hitFilterIndex: 0
    property bool callDetailExpanded: true
    property bool breakpointPanelExpanded: true
    property var selectedItem: filterItems().length > 0 ? filterItems()[Math.max(0, table.currentIndex)] : null
    property int detailTabIndex: 0

    function statusText(status) {
        if (status === "finished") return "成功"
        if (status === "paused") return "已暂停"
        if (status === "exception") return "异常"
        if (status === "continued") return "继续中"
        return status || "-"
    }

    function statusColor(status) {
        if (status === "finished") return green
        if (status === "paused") return amber
        if (status === "exception") return red
        return textMuted
    }

    function shortTime(value) {
        if (!value) return "-"
        return String(value).replace("T", " ").split("+")[0]
    }

    function breakpointById(id) {
        if (!id) return null
        for (var i = 0; i < breakpoints.length; i++) {
            if (breakpoints[i].id === id) return breakpoints[i]
        }
        return null
    }

    function breakpointEnabled(id) {
        var bp = breakpointById(id)
        return bp ? !!bp.enabled : false
    }

    function statusFilterValue() {
        var values = ["", "finished", "paused", "exception", "continued"]
        return values[statusFilterIndex] || ""
    }

    function filterItems() {
        var result = []
        var keyword = searchText.toLowerCase()
        var status = statusFilterValue()
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            var haystack = ((item.method_name || "") + " " + (item.class_name || "") + " " + (item.thread_name || "") + " " + (item.display_name || "")).toLowerCase()
            if (keyword.length > 0 && haystack.indexOf(keyword) < 0) continue
            if (status.length > 0 && item.status !== status) continue
            if (hitFilterIndex === 1 && !item.breakpoint_id) continue
            if (hitFilterIndex === 2 && item.breakpoint_id) continue
            result.push(item)
        }
        return result
    }

    component MiniSwitch: Rectangle {
        id: sw
        property bool checked: false
        property bool enabledSwitch: true
        signal toggled(bool checked)
        width: 42
        height: 22
        radius: 11
        color: checked ? "#1f6feb" : "#26313d"
        border.color: checked ? "#58a6ff" : "#4b5563"
        opacity: enabledSwitch ? 1 : 0.45
        Rectangle {
            width: 16
            height: 16
            radius: 8
            color: "#e8eef5"
            anchors.verticalCenter: parent.verticalCenter
            x: sw.checked ? 22 : 4
            Behavior on x { NumberAnimation { duration: 110 } }
        }
        MouseArea {
            anchors.fill: parent
            enabled: sw.enabledSwitch
            onClicked: sw.toggled(!sw.checked)
        }
    }

    component SegmentButton: Button {
        id: seg
        property bool selected: false
        implicitHeight: 38
        padding: 0
        font.pixelSize: 13
        font.weight: Font.DemiBold
        background: Rectangle {
            color: seg.selected ? "#1f5fb9" : (seg.hovered ? "#182333" : "#10161d")
            border.color: seg.selected ? "#58a6ff" : page.border
        }
        contentItem: Text {
            text: seg.text
            color: seg.selected ? "#ffffff" : page.textNormal
            font: seg.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    component FilterCombo: ComboBox {
        id: combo
        property string prefix: ""
        implicitHeight: 38
        padding: 0
        font.pixelSize: 14
        background: Rectangle {
            radius: 4
            color: combo.pressed ? "#182333" : "#10161d"
            border.color: combo.visualFocus ? page.blue : page.border
        }
        contentItem: Text {
            text: combo.prefix + combo.displayText
            color: page.textNormal
            font: combo.font
            verticalAlignment: Text.AlignVCenter
            leftPadding: 12
            rightPadding: 28
            elide: Text.ElideRight
        }
        indicator: Text {
            text: "⌄"
            color: page.textMuted
            font.pixelSize: 14
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 10
        }
        delegate: ItemDelegate {
            width: combo.width
            height: 34
            highlighted: combo.highlightedIndex === index
            background: Rectangle { color: highlighted ? "#173052" : (hovered ? "#182333" : "#10161d") }
            contentItem: Text {
                text: modelData
                color: highlighted ? "#cfe6ff" : page.textNormal
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                leftPadding: 12
            }
        }
        popup: Popup {
            y: combo.height + 4
            width: combo.width
            implicitHeight: Math.min(contentItem.implicitHeight + 2, 220)
            padding: 1
            background: Rectangle { color: "#10161d"; border.color: page.border; radius: 4 }
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 7; radius: 4; color: parent.pressed ? page.blue : "#4b5563" }
                    background: Rectangle { color: "#0d1218"; radius: 4 }
                }
            }
        }
    }

    component HeaderCell: Rectangle {
        property string label: ""
        color: "#20262e"
        border.color: page.border
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: parent.label
            color: page.textStrong
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
    }

    component DataCell: Rectangle {
        property string label: ""
        property color labelColor: page.textNormal
        color: "transparent"
        border.color: page.border
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            text: parent.label
            color: parent.labelColor
            font.pixelSize: 14
            elide: Text.ElideRight
        }
    }

    component StatusBadge: Rectangle {
        property string status: ""
        width: 58
        height: 24
        radius: 4
        color: Qt.rgba(statusColor(status).r, statusColor(status).g, statusColor(status).b, 0.16)
        border.color: statusColor(status)
        Text {
            anchors.centerIn: parent
            text: statusText(parent.status)
            color: statusColor(parent.status)
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

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
                    Layout.preferredHeight: 62
                    color: panel
                    border.color: border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14
                        TextField {
                            id: searchInput
                            Layout.preferredWidth: 230
                            Layout.preferredHeight: 38
                            placeholderText: "搜索方法名、类名、线程名..."
                            text: page.searchText
                            color: textStrong
                            placeholderTextColor: textMuted
                            font.pixelSize: 14
                            selectByMouse: true
                            onTextChanged: page.searchText = text
                            background: Rectangle { radius: 4; color: "#10161d"; border.color: border }
                        }
                        FilterCombo {
                            id: statusBox
                            Layout.preferredWidth: 122
                            Layout.preferredHeight: 38
                            prefix: "状态: "
                            model: ["全部", "成功", "已暂停", "异常", "继续中"]
                            currentIndex: page.statusFilterIndex
                            onActivated: page.statusFilterIndex = currentIndex
                        }
                        FilterCombo {
                            id: hitBox
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 38
                            prefix: "命中断点: "
                            model: ["全部", "命中", "未命中"]
                            currentIndex: page.hitFilterIndex
                            onActivated: page.hitFilterIndex = currentIndex
                        }
                        Item { Layout.fillWidth: true }
                        Button {
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 38
                            text: "刷新"
                            font.pixelSize: 13
                            onClicked: bridge.refreshAll()
                            background: Rectangle { radius: 4; color: parent.hovered ? "#1d2631" : "#10161d"; border.color: border }
                            contentItem: Text { text: parent.text; color: textMuted; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 38
                            text: "清空记录"
                            enabled: page.canClearRecords && items.length > 0
                            font.pixelSize: 13
                            onClicked: bridge.clearCalls()
                            background: Rectangle { radius: 4; color: parent.enabled ? (parent.hovered ? "#5a1f2a" : "#2b1720") : "#151b23"; border.color: parent.enabled ? "#7f2d3a" : "#222a33" }
                            contentItem: Text { text: parent.text; color: parent.enabled ? "#ffb4b4" : "#687483"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    spacing: 0
                    HeaderCell { label: "序号"; Layout.preferredWidth: 58; Layout.preferredHeight: 46 }
                            HeaderCell { label: "方法名"; Layout.preferredWidth: 150; Layout.preferredHeight: 46 }
                            HeaderCell { label: "中文描述"; Layout.preferredWidth: 104; Layout.preferredHeight: 46 }
                            HeaderCell { label: "接口别名"; Layout.preferredWidth: 126; Layout.preferredHeight: 46 }
                            HeaderCell { label: "状态"; Layout.preferredWidth: 76; Layout.preferredHeight: 46 }
                            HeaderCell { label: "耗时(ms)"; Layout.preferredWidth: 84; Layout.preferredHeight: 46 }
                            HeaderCell { label: "线程名"; Layout.fillWidth: true; Layout.preferredHeight: 46 }
                            HeaderCell { label: "调用时间"; Layout.preferredWidth: 134; Layout.preferredHeight: 46 }
                            HeaderCell { label: "命中断点"; Layout.preferredWidth: 112; Layout.preferredHeight: 46 }
                }

                ListView {
                    id: table
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: page.filterItems()
                    clip: true
                    currentIndex: page.filterItems().length > 0 ? Math.max(0, currentIndex) : -1
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: table.width
                        height: 52
                        color: table.currentIndex === index
                               ? (modelData.status === "paused" ? "#4c4714" : "#173052")
                               : (modelData.status === "paused" ? "#393716" : (index % 2 ? "#151c24" : "#111820"))
                        border.color: page.border

                        MouseArea {
                            anchors.fill: parent
                            onClicked: table.currentIndex = index
                        }

                        GridLayout {
                            anchors.fill: parent
                            columns: 9
                            rowSpacing: 0
                            columnSpacing: 0
                            DataCell { label: String(modelData.call_index || index + 1); labelColor: modelData.status === "paused" ? page.amber : page.textNormal; Layout.preferredWidth: 58; Layout.fillHeight: true }
                            DataCell { label: modelData.method_name || "-"; labelColor: modelData.status === "exception" ? page.red : (modelData.status === "paused" ? page.amber : page.textStrong); Layout.preferredWidth: 150; Layout.fillHeight: true }
                            DataCell { label: modelData.display_name || "-"; Layout.preferredWidth: 104; Layout.fillHeight: true }
                            Rectangle {
                                Layout.preferredWidth: 126
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: page.border
                                TextField {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: modelData.interface_alias || ""
                                    placeholderText: "未命名"
                                    color: page.textStrong
                                    placeholderTextColor: page.textMuted
                                    font.pixelSize: 13
                                    selectByMouse: true
                                    enabled: !!modelData.interface_id
                                    onEditingFinished: {
                                        if (modelData.interface_id && text !== (modelData.interface_alias || "")) {
                                            bridge.setCallAlias(modelData.call_id, text)
                                        }
                                    }
                                    background: Rectangle { radius: 4; color: parent.enabled ? "#10161d" : "transparent"; border.color: parent.activeFocus ? page.blue : "transparent" }
                                }
                            }
                            Rectangle {
                                Layout.preferredWidth: 76
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: page.border
                                StatusBadge { status: modelData.status || ""; anchors.centerIn: parent }
                            }
                            DataCell { label: modelData.cost_ms === null || modelData.cost_ms === undefined ? "-" : String(modelData.cost_ms); Layout.preferredWidth: 84; Layout.fillHeight: true }
                            DataCell { label: modelData.thread_name || "-"; Layout.fillWidth: true; Layout.fillHeight: true }
                            DataCell { label: shortTime(modelData.created_at); Layout.preferredWidth: 134; Layout.fillHeight: true }
                            Rectangle {
                                Layout.preferredWidth: 112
                                Layout.fillHeight: true
                                color: "transparent"
                                border.color: page.border
                                Row {
                                    anchors.centerIn: parent
                                    Text {
                                        text: modelData.breakpoint_id ? "命中" : "未命中"
                                        color: modelData.breakpoint_id ? page.amber : page.textMuted
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    color: "#111820"
                    border.color: border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        Text { text: "共 " + page.filterItems().length + " / " + items.length + " 条"; color: textNormal; font.pixelSize: 15 }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "‹"
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            background: Rectangle { radius: 4; color: "#10161d"; border.color: border }
                            contentItem: Text { text: parent.text; color: textMuted; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 36
                            color: "#143f75"
                            border.color: blue
                            radius: 4
                            Text { anchors.centerIn: parent; text: "1"; color: "#cfe6ff"; font.pixelSize: 16 }
                        }
                        Button {
                            text: "›"
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            background: Rectangle { radius: 4; color: "#10161d"; border.color: border }
                            contentItem: Text { text: parent.text; color: textMuted; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Rectangle {
                            Layout.preferredWidth: 98
                            Layout.preferredHeight: 36
                            radius: 4
                            color: "#10161d"
                            border.color: border
                            Text { anchors.centerIn: parent; text: "20 条/页"; color: textNormal; font.pixelSize: 14 }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 488
            Layout.fillHeight: true
            color: panel
            border.color: border
            radius: 3

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    color: panel
                    border.color: border
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "调用详情"; color: textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 14; text: page.callDetailExpanded ? "⌃" : "⌄"; color: textMuted; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: page.callDetailExpanded = !page.callDetailExpanded }
                }

                GridLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.callDetailExpanded ? 246 : 0
                    visible: page.callDetailExpanded
                    columns: 2
                    rowSpacing: 8
                    columnSpacing: 12
                    Layout.margins: 14

                    Repeater {
                        model: [
                            ["callId", selectedItem ? selectedItem.call_id : "-"],
                            ["serviceName", selectedItem ? selectedItem.service_name : "-"],
                            ["className", selectedItem ? selectedItem.class_name : "-"],
                            ["methodName", selectedItem ? selectedItem.method_name : "-"],
                            ["displayName", selectedItem ? selectedItem.display_name : "-"],
                            ["status", selectedItem ? statusText(selectedItem.status) : "-"],
                            ["线程名", selectedItem ? selectedItem.thread_name : "-"],
                            ["调用时间", selectedItem ? shortTime(selectedItem.created_at) : "-"],
                            ["costMs", selectedItem && selectedItem.cost_ms ? selectedItem.cost_ms : "-"]
                        ]
                        delegate: Item {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            Layout.columnSpan: 2
                            RowLayout {
                                anchors.fill: parent
                                spacing: 8
                                Text { text: modelData[0]; color: textNormal; font.pixelSize: 13; Layout.preferredWidth: 96; elide: Text.ElideRight }
                                Text { text: modelData[1]; color: modelData[0] === "status" ? (selectedItem ? statusColor(selectedItem.status) : textMuted) : textStrong; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.callDetailExpanded ? 1 : 0
                    visible: page.callDetailExpanded
                    color: border
                }

                RowLayout {
                    id: detailTabs
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 0
                    SegmentButton {
                        text: "参数 (args)"
                        selected: page.detailTabIndex === 0
                        Layout.preferredWidth: 126
                        onClicked: page.detailTabIndex = 0
                    }
                    SegmentButton {
                        text: "返回值 (result)"
                        selected: page.detailTabIndex === 1
                        Layout.preferredWidth: 142
                        onClicked: page.detailTabIndex = 1
                    }
                    SegmentButton {
                        text: "异常 (exception)"
                        selected: page.detailTabIndex === 2
                        Layout.preferredWidth: 154
                        onClicked: page.detailTabIndex = 2
                    }
                    Item { Layout.fillWidth: true }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#0f151c"
                    border.color: border
                    ScrollView {
                        anchors.fill: parent
                        anchors.margins: 8
                        clip: true
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle { implicitWidth: 8; radius: 4; color: parent.pressed ? page.blue : "#4b5563" }
                            background: Rectangle { color: "#0d1218"; radius: 4 }
                        }
                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle { implicitHeight: 8; radius: 4; color: parent.pressed ? page.blue : "#4b5563" }
                            background: Rectangle { color: "#0d1218"; radius: 4 }
                        }
                        TextArea {
                            readOnly: true
                            selectByMouse: true
                            text: selectedItem
                                  ? (page.detailTabIndex === 0 ? JSON.stringify(selectedItem.args || {}, null, 2)
                                     : page.detailTabIndex === 1 ? JSON.stringify(selectedItem.result || {}, null, 2)
                                     : JSON.stringify({exceptionType: selectedItem.exception_type, exceptionMessage: selectedItem.exception_message}, null, 2))
                                  : "{}"
                            color: "#b6e3ff"
                            selectedTextColor: "#ffffff"
                            selectionColor: "#1f6feb"
                            font.family: "Consolas"
                            font.pixelSize: 13
                            background: Rectangle { color: "transparent" }
                            wrapMode: TextArea.NoWrap
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    color: panel
                    border.color: border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        Button {
                            text: "继续执行"
                            enabled: selectedItem && selectedItem.status === "paused"
                            Layout.fillWidth: true
                            onClicked: bridge.continueCall(selectedItem.call_id)
                            background: Rectangle { radius: 4; color: parent.enabled ? "#1f5fb9" : "#1a2430"; border.color: parent.enabled ? "#58a6ff" : border }
                            contentItem: Text { text: parent.text; color: parent.enabled ? "#ffffff" : textMuted; font.pixelSize: 14; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Button {
                            text: "按参数创建断点"
                            enabled: selectedItem !== null
                            Layout.fillWidth: true
                            onClicked: bridge.createBreakpointFromCall(selectedItem.call_id)
                            background: Rectangle { radius: 4; color: parent.enabled ? "#1d4f96" : "#1a2430"; border.color: parent.enabled ? "#58a6ff" : border }
                            contentItem: Text { text: parent.text; color: parent.enabled ? "#ffffff" : textMuted; font.pixelSize: 14; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    color: panel
                    border.color: border
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "断点列表 (" + breakpoints.length + ")"; color: textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 14; text: page.breakpointPanelExpanded ? "⌃" : "⌄"; color: textMuted; font.pixelSize: 16 }
                    MouseArea { anchors.fill: parent; onClicked: page.breakpointPanelExpanded = !page.breakpointPanelExpanded }
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.breakpointPanelExpanded ? 176 : 0
                    visible: page.breakpointPanelExpanded
                    model: breakpoints
                    clip: true
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: parent ? parent.width : 480
                        height: 58
                        color: index % 2 ? "#121920" : "#10161d"
                        border.color: border
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 12
                            Rectangle { width: 10; height: 10; radius: 5; color: modelData.enabled ? red : textMuted }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: modelData.id + "   " + modelData.method_name; color: textStrong; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.class_name || "-"; color: textMuted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Text { text: modelData.enabled ? "开" : "关"; color: modelData.enabled ? "#cfe6ff" : textMuted; font.pixelSize: 13 }
                            MiniSwitch {
                                checked: !!modelData.enabled
                                onToggled: function(value) { bridge.setBreakpointEnabled(modelData.id, value) }
                            }
                            Button {
                                text: "×"
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 28
                                onClicked: bridge.deleteBreakpoint(modelData.id)
                                background: Rectangle { radius: 4; color: parent.hovered ? "#5a1f2a" : "#2b1720"; border.color: "#7f2d3a" }
                                contentItem: Text { text: parent.text; color: "#ffb4b4"; font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                }
            }
        }
    }
}
