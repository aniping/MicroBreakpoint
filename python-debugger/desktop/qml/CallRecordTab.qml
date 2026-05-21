import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page
    property var appTheme
    property var items: []
    property var breakpoints: []
    property bool canClearRecords: false
    property color bg: appTheme.windowBg
    property color panel: appTheme.panelBg
    property color panel2: appTheme.panelBgAlt
    property color border: appTheme.border
    property color textStrong: appTheme.textStrong
    property color textNormal: appTheme.textNormal
    property color textMuted: appTheme.textMuted
    property color blue: appTheme.primary
    property color green: appTheme.success
    property color red: appTheme.danger
    property color amber: appTheme.warning
    property string searchText: ""
    property int statusFilterIndex: 0
    property int hitFilterIndex: 0
    property bool callDetailExpanded: true
    property bool breakpointPanelExpanded: true
    property var selectedItem: filterItems().length > 0 ? filterItems()[Math.max(0, table.currentIndex)] : null
    property int detailTabIndex: 0

    function statusText(status) {
        if (status === "running") return "运行中"
        if (status === "finished") return "成功"
        if (status === "paused") return "已暂停"
        if (status === "exception") return "异常"
        if (status === "continued") return "继续中"
        if (status === "timeout") return "超时"
        if (status === "ignored") return "忽略"
        return status || "-"
    }

    function statusColor(status) {
        if (status === "running") return blue
        if (status === "finished") return green
        if (status === "paused") return amber
        if (status === "continued") return blue
        if (status === "exception") return red
        if (status === "timeout") return amber
        return textMuted
    }

    function statusType(status) {
        if (status === "finished") return "success"
        if (status === "paused") return "warning"
        if (status === "exception") return "danger"
        if (status === "timeout") return "warning"
        if (status === "running" || status === "continued") return "primary"
        return "neutral"
    }

    function detailText() {
        if (!selectedItem) return "{}"
        if (page.detailTabIndex === 0) return JSON.stringify(selectedItem.args || {}, null, 2)
        if (page.detailTabIndex === 1) return JSON.stringify(selectedItem.result || {}, null, 2)
        return JSON.stringify({exceptionType: selectedItem.exception_type, exceptionMessage: selectedItem.exception_message}, null, 2)
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
        var values = ["", "running", "paused", "continued", "finished", "exception", "timeout", "ignored"]
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

    component SegmentButton: Button {
        id: seg
        property bool selected: false
        implicitHeight: 38
        padding: 0
        font.pixelSize: 13
        font.weight: Font.DemiBold
        background: Rectangle {
            color: seg.selected ? page.appTheme.primary : (seg.hovered ? page.appTheme.panelHover : page.appTheme.panelBgAlt)
            border.color: seg.selected ? page.appTheme.primaryHover : page.border
        }
        contentItem: Text {
            text: seg.text
            color: seg.selected ? page.appTheme.onAccent : page.textNormal
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
            color: combo.pressed ? page.appTheme.panelHover : page.appTheme.inputBg
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
            background: Rectangle { color: highlighted ? page.appTheme.panelActive : (hovered ? page.appTheme.panelHover : page.appTheme.panelBg) }
            contentItem: Text {
                text: modelData
                color: highlighted ? page.appTheme.textStrong : page.textNormal
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
            background: Rectangle { color: page.appTheme.panelBg; border.color: page.border; radius: 4 }
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 7; radius: 4; color: parent.pressed ? page.blue : page.appTheme.textDisabled }
                    background: Rectangle { color: page.appTheme.panelBgAlt; radius: 4 }
                }
            }
        }
    }

    component HeaderCell: Rectangle {
        property string label: ""
        color: page.appTheme.panelBgAlt
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
        width: 64
        height: 24
        radius: 4
        color: statusType(status) === "success" ? page.appTheme.successSoft
              : statusType(status) === "warning" ? page.appTheme.warningSoft
              : statusType(status) === "danger" ? page.appTheme.dangerSoft
              : statusType(status) === "primary" ? page.appTheme.primarySoft
              : page.appTheme.panelBgAlt
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
            color: page.panel
            border.color: page.border
            radius: 3

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    color: page.panel
                    border.color: page.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 14
                        MbTextField {
                            id: searchInput
                            appTheme: page.appTheme
                            Layout.preferredWidth: 230
                            Layout.preferredHeight: 38
                            placeholderText: "搜索方法名、类名、线程名..."
                            text: page.searchText
                            onTextChanged: page.searchText = text
                        }
                        FilterCombo {
                            id: statusBox
                            Layout.preferredWidth: 122
                            Layout.preferredHeight: 38
                            prefix: "状态: "
                            model: ["全部", "运行中", "已暂停", "继续中", "成功", "异常", "超时", "忽略"]
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
                        MbButton {
                            appTheme: page.appTheme
                            Layout.preferredWidth: 44
                            Layout.preferredHeight: 38
                            text: "刷新"
                            variant: "neutral"
                            onClicked: bridge.refreshAll()
                        }
                        MbButton {
                            appTheme: page.appTheme
                            Layout.preferredWidth: 92
                            Layout.preferredHeight: 38
                            text: "清空记录"
                            variant: "danger"
                            enabled: page.canClearRecords && items.length > 0
                            onClicked: bridge.clearCalls()
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
                               ? (modelData.status === "paused" ? page.appTheme.warningSoft : page.appTheme.panelActive)
                               : (modelData.status === "paused" ? page.appTheme.warningSoft : (index % 2 ? page.appTheme.panelBgAlt : page.appTheme.panelBg))
                        border.color: page.appTheme.borderSoft

                        MouseArea {
                            anchors.fill: parent
                            onClicked: table.currentIndex = index
                        }

                        Rectangle {
                            width: 3
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            visible: modelData.status === "paused"
                            color: page.amber
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
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    height: 26
                                    radius: 4
                                    color: modelData.interface_alias ? page.appTheme.primarySoft : "transparent"
                                    border.color: modelData.interface_alias ? page.appTheme.primary : "transparent"
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        text: modelData.interface_alias || "未命名"
                                        color: modelData.interface_alias ? page.appTheme.textStrong : page.textMuted
                                        font.pixelSize: 13
                                        font.weight: modelData.interface_alias ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }
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
                    color: page.appTheme.panelBgAlt
                    border.color: page.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 18
                        anchors.rightMargin: 18
                        Text { text: "共 " + page.filterItems().length + " / " + items.length + " 条"; color: page.textNormal; font.pixelSize: 15 }
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "‹"
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            background: Rectangle { radius: 4; color: page.appTheme.inputBg; border.color: page.border }
                            contentItem: Text { text: parent.text; color: page.textMuted; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Rectangle {
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 36
                            color: page.appTheme.primarySoft
                            border.color: page.blue
                            radius: 4
                            Text { anchors.centerIn: parent; text: "1"; color: page.appTheme.primary; font.pixelSize: 16; font.weight: Font.DemiBold }
                        }
                        Button {
                            text: "›"
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            background: Rectangle { radius: 4; color: page.appTheme.inputBg; border.color: page.border }
                            contentItem: Text { text: parent.text; color: page.textMuted; font.pixelSize: 20; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                        Rectangle {
                            Layout.preferredWidth: 98
                            Layout.preferredHeight: 36
                            radius: 4
                            color: page.appTheme.inputBg
                            border.color: page.border
                            Text { anchors.centerIn: parent; text: "20 条/页"; color: page.textNormal; font.pixelSize: 14 }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 488
            Layout.fillHeight: true
            color: page.panel
            border.color: page.border
            radius: 3

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    color: page.panel
                    border.color: page.border
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "调用详情"; color: page.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 14; text: page.callDetailExpanded ? "⌃" : "⌄"; color: page.textMuted; font.pixelSize: 16 }
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
                                Text { text: modelData[0]; color: page.textNormal; font.pixelSize: 13; Layout.preferredWidth: 96; elide: Text.ElideRight }
                                Text { text: modelData[1]; color: modelData[0] === "status" ? (selectedItem ? statusColor(selectedItem.status) : page.textMuted) : page.textStrong; font.pixelSize: 13; Layout.fillWidth: true; elide: Text.ElideRight }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: page.callDetailExpanded ? 1 : 0
                    visible: page.callDetailExpanded
                    color: page.border
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

                MbJsonViewer {
                    appTheme: page.appTheme
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    text: page.detailText()
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 112
                    color: page.panel
                    border.color: page.border
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 10
                        MbButton {
                            appTheme: page.appTheme
                            text: "继续执行"
                            enabled: selectedItem && selectedItem.status === "paused"
                            variant: "primary"
                            Layout.fillWidth: true
                            onClicked: bridge.continueCall(selectedItem.call_id)
                        }
                        MbButton {
                            appTheme: page.appTheme
                            text: "按方法创建断点"
                            enabled: selectedItem !== null
                            variant: "primary"
                            Layout.fillWidth: true
                            onClicked: bridge.createMethodBreakpointFromCall(selectedItem.call_id)
                        }
                        MbButton {
                            appTheme: page.appTheme
                            text: "按本次参数创建断点"
                            enabled: selectedItem !== null
                            variant: "primary"
                            Layout.fillWidth: true
                            onClicked: bridge.createBreakpointFromCall(selectedItem.call_id)
                        }
                        MbButton {
                            appTheme: page.appTheme
                            text: "复制入参"
                            enabled: selectedItem !== null
                            variant: "neutral"
                            Layout.fillWidth: true
                            onClicked: bridge.copyText(JSON.stringify(selectedItem.args || {}, null, 2))
                        }
                        MbButton {
                            appTheme: page.appTheme
                            text: "复制返回值"
                            enabled: selectedItem !== null
                            variant: "neutral"
                            Layout.fillWidth: true
                            onClicked: bridge.copyText(JSON.stringify(selectedItem.result || {}, null, 2))
                        }
                        MbButton {
                            appTheme: page.appTheme
                            text: "刷新详情"
                            variant: "neutral"
                            Layout.fillWidth: true
                            onClicked: bridge.refreshAll()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    color: page.panel
                    border.color: page.border
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "断点列表 (" + breakpoints.length + ")"; color: page.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 14; text: page.breakpointPanelExpanded ? "⌃" : "⌄"; color: page.textMuted; font.pixelSize: 16 }
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
                        color: index % 2 ? page.appTheme.panelBgAlt : page.appTheme.panelBg
                        border.color: page.border
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 12
                            Rectangle { width: 10; height: 10; radius: 5; color: modelData.enabled ? page.green : page.textMuted }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: modelData.id + "   " + modelData.method_name; color: page.textStrong; font.pixelSize: 14; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text { text: modelData.class_name || "-"; color: page.textMuted; font.pixelSize: 12; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                            Text { text: modelData.enabled ? "开" : "关"; color: modelData.enabled ? page.green : page.textMuted; font.pixelSize: 13 }
                            MbSwitch {
                                appTheme: page.appTheme
                                checked: !!modelData.enabled
                                onToggled: function(value) { bridge.setBreakpointEnabled(modelData.id, value) }
                            }
                            MbButton {
                                appTheme: page.appTheme
                                text: "×"
                                variant: "danger"
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 28
                                onClicked: bridge.deleteBreakpoint(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
