import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page

    property var appTheme
    property var items: []
    property var calls: []
    property string selectedBreakpointId: ""
    property int detailTabIndex: 0
    property string objectFilter: "全部"
    property string statusFilter: "全部"
    property string sourceFilter: "全部"
    property string searchText: ""
    property var expandedGroups: ({})
    property var selectedItem: selectedItemForId(selectedBreakpointId)
    signal requestCallFilter(string breakpointId)

    function cloneObject(value) {
        var next = {}
        for (var key in (value || {})) next[key] = value[key]
        return next
    }
    function safeObject(value, fallback) {
        if (value === undefined || value === null || value === "") return fallback
        if (typeof value === "string") {
            try { return JSON.parse(value) } catch (e) { return fallback }
        }
        return value
    }
    function jsonText(value) {
        if (value === undefined || value === null || value === "") return "{}"
        if (typeof value === "string") {
            try { return JSON.stringify(JSON.parse(value), null, 2) } catch (e) { return value }
        }
        try { return JSON.stringify(value, null, 2) } catch (e2) { return String(value) }
    }
    function textOf(value) {
        if (value === undefined || value === null || value === "") return "-"
        return String(value)
    }
    function itemId(item) { return item ? String(item.id || item.breakpoint_id || item.breakpointId || "") : "" }
    function objectName(item) { return String(item ? (item.object_name || item.objectName || "未分类") : "未分类") }
    function cmdName(item) { return String(item ? (item.cmd_name || item.cmdName || item.method_name || item.methodName || "-") : "-") }
    function slotText(item) {
        var value = item ? (item.slot_id !== undefined ? item.slot_id : item.slotId) : undefined
        return value === undefined || value === null || value === "" ? "无槽位" : String(value)
    }
    function sourceText(item) {
        if (!item) return "手工创建"
        if (item.source_interface_id || item.sourceInterfaceId) return "已发现接口"
        if (item.source_call_id || item.sourceCallId) return "调用记录"
        return "手工创建"
    }
    function shortTime(value) {
        if (!value) return "-"
        return String(value).replace("T", " ").split("+")[0]
    }
    function matchModeText(mode) {
        if (mode === "params_snapshot") return "参数快照"
        if (mode === "params_condition") return "参数条件"
        return "命令"
    }
    function statusText(status) {
        if (status === "running") return "运行中"
        if (status === "finished") return "成功"
        if (status === "paused") return "暂停"
        if (status === "exception") return "异常"
        if (status === "continued") return "继续"
        if (status === "timeout") return "超时"
        return status || "-"
    }
    function statusType(status) {
        if (status === "finished") return "success"
        if (status === "paused" || status === "timeout") return "warning"
        if (status === "exception") return "danger"
        if (status === "running" || status === "continued") return "primary"
        return "neutral"
    }
    function rangeText(item) {
        return objectName(item) + " / " + cmdName(item) + " / 槽位 " + slotText(item) + " / " + matchModeText(item ? item.match_mode : "")
    }
    function selectedItemForId(id) {
        if (items.length === 0) return null
        if (id) {
            for (var i = 0; i < items.length; i++) if (itemId(items[i]) === id) return items[i]
        }
        return items[0]
    }
    function ensureSelection() {
        if (items.length === 0) {
            selectedBreakpointId = ""
            return
        }
        if (selectedBreakpointId && selectedItemForId(selectedBreakpointId) && itemId(selectedItemForId(selectedBreakpointId)) === selectedBreakpointId) return
        selectedBreakpointId = itemId(items[0])
    }
    onItemsChanged: Qt.callLater(ensureSelection)

    function objectOptions() {
        var seen = {"全部": true}
        var result = ["全部"]
        for (var i = 0; i < items.length; i++) {
            var name = objectName(items[i])
            if (!seen[name]) {
                seen[name] = true
                result.push(name)
            }
        }
        return result
    }

    function isExpanded(name) { return expandedGroups[name] !== false }
    function setExpanded(name, value) {
        var next = cloneObject(expandedGroups)
        next[name] = value
        expandedGroups = next
    }

    function filteredItems() {
        var needle = searchText.toLowerCase()
        var result = []
        for (var i = 0; i < items.length; i++) {
            var item = items[i]
            if (objectFilter !== "全部" && objectName(item) !== objectFilter) continue
            if (statusFilter === "已启用" && !item.enabled) continue
            if (statusFilter === "已禁用" && item.enabled) continue
            if (sourceFilter !== "全部" && sourceText(item) !== sourceFilter) continue
            var haystack = ((item.name || "") + " " + objectName(item) + " " + cmdName(item) + " " + slotText(item) + " " + rangeText(item)).toLowerCase()
            if (needle && haystack.indexOf(needle) < 0) continue
            result.push(item)
        }
        return result
    }

    function groups() {
        var rows = filteredItems()
        var map = {}
        for (var i = 0; i < rows.length; i++) {
            var name = objectName(rows[i])
            if (!map[name]) map[name] = {objectName: name, rows: [], enabledCount: 0, disabledCount: 0, hitTotal: 0}
            map[name].rows.push(rows[i])
            if (rows[i].enabled) map[name].enabledCount++
            else map[name].disabledCount++
            map[name].hitTotal += Number(rows[i].hit_count || rows[i].hitCount || 0)
        }
        var result = []
        for (var key in map) result.push(map[key])
        result.sort(function(a, b) { return a.objectName.localeCompare(b.objectName) })
        return result
    }

    function hitRecords(item) {
        var id = itemId(item)
        var result = []
        for (var i = 0; i < calls.length; i++) {
            var callBp = String(calls[i].breakpoint_id || calls[i].breakpointId || "")
            if (callBp === id) result.push(calls[i])
        }
        result.sort(function(a, b) { return Number(b.call_index || 0) - Number(a.call_index || 0) })
        return result.slice(0, 10)
    }

    function conditionLines(item) {
        if (!item) return ["无附加参数条件，命中该命令即暂停。"]
        var condition = safeObject(item.condition || item.condition_json || {}, {})
        var conditions = safeObject(item.conditions || item.conditions_json || [], [])
        var snapshot = safeObject(item.params_snapshot || item.params_snapshot_json || {}, {})
        var lines = []
        if (Object.keys(condition).length > 0) {
            for (var key in condition) lines.push(key + " = " + condition[key])
        }
        if (conditions.length > 0) {
            for (var i = 0; i < conditions.length; i++) lines.push(jsonText(conditions[i]).replace(/\s+/g, " "))
        }
        if (Object.keys(snapshot).length > 0) lines.push("params = " + jsonText(snapshot).replace(/\s+/g, " "))
        if (lines.length === 0) lines.push("无附加参数条件，命中该命令即暂停。")
        return lines
    }

    function overviewRows(item) {
        return [
            ["断点名称", textOf(item ? item.name : "")],
            ["objectName", objectName(item)],
            ["cmdName", cmdName(item)],
            ["slotId", slotText(item)],
            ["sessionId", textOf(item ? (item.session_id || item.sessionId) : "")],
            ["状态", item && item.enabled ? "已启用" : "已禁用"],
            ["匹配方式", matchModeText(item ? item.match_mode : "")],
            ["命中次数", textOf(item ? (item.hit_count || item.hitCount || 0) : 0)],
            ["来源", sourceText(item)],
            ["创建时间", shortTime(item ? (item.created_at || item.createdAt) : "")],
            ["更新时间", shortTime(item ? (item.updated_at || item.updatedAt) : "")]
        ]
    }

    function overviewIdentityRows(item) {
        return [
            ["断点名称", textOf(item ? item.name : "")],
            ["objectName", objectName(item)],
            ["cmdName", cmdName(item)],
            ["slotId", slotText(item)],
            ["sessionId", textOf(item ? (item.session_id || item.sessionId) : "")]
        ]
    }

    function overviewStateRows(item) {
        return [
            ["状态", item && item.enabled ? "已启用" : "已禁用"],
            ["匹配方式", matchModeText(item ? item.match_mode : "")],
            ["命中次数", textOf(item ? (item.hit_count || item.hitCount || 0) : 0)],
            ["来源", sourceText(item)]
        ]
    }

    function overviewTimeRows(item) {
        return [
            ["创建时间", shortTime(item ? (item.created_at || item.createdAt) : "")],
            ["更新时间", shortTime(item ? (item.updated_at || item.updatedAt) : "")]
        ]
    }

    function setAllBreakpoints(enabled) {
        for (var i = 0; i < filteredItems().length; i++) bridge.setBreakpointEnabled(itemId(filteredItems()[i]), enabled)
    }

    function confirmDeleteBreakpoint(breakpointId, breakpointName) {
        confirmDialog.ask("删除断点", "将删除断点 " + breakpointName + "。此操作不可撤销。", "删除", function() {
            bridge.deleteBreakpoint(breakpointId)
        })
    }

    ConfirmDialog {
        id: confirmDialog
        appTheme: page.appTheme
    }

    component FilterCombo: ComboBox {
        id: combo
        implicitHeight: 34
        padding: 0
        font.pixelSize: 13
        background: Rectangle { radius: 4; color: combo.pressed ? page.appTheme.panelHover : page.appTheme.inputBg; border.color: page.appTheme.border }
        contentItem: Text { text: combo.displayText; color: page.appTheme.textNormal; font: combo.font; verticalAlignment: Text.AlignVCenter; leftPadding: 10; rightPadding: 26; elide: Text.ElideRight }
        indicator: Text { text: "⌄"; color: page.appTheme.textMuted; anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 8 }
    }

    component TabButton: Button {
        id: tab
        property bool selected: false
        implicitHeight: 38
        padding: 0
        background: Rectangle { color: tab.selected ? page.appTheme.primary : (tab.hovered ? page.appTheme.panelHover : page.appTheme.panelBgAlt); border.color: tab.selected ? page.appTheme.primary : page.appTheme.border }
        contentItem: Text { text: tab.text; color: tab.selected ? page.appTheme.onAccent : page.appTheme.textNormal; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 620
            Layout.fillHeight: true
            color: appTheme.panelBg
            border.color: appTheme.border
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 50
                    color: appTheme.panelBg
                    border.color: appTheme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 10
                        Text { text: "断点管理"; color: appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.preferredWidth: 78; elide: Text.ElideRight }
                        FilterCombo { Layout.preferredWidth: 100; model: page.objectOptions(); currentIndex: Math.max(0, model.indexOf(page.objectFilter)); onActivated: page.objectFilter = currentText }
                        FilterCombo { Layout.preferredWidth: 92; model: ["全部", "已启用", "已禁用"]; currentIndex: Math.max(0, model.indexOf(page.statusFilter)); onActivated: page.statusFilter = currentText }
                        FilterCombo { Layout.preferredWidth: 108; model: ["全部", "已发现接口", "调用记录", "手工创建"]; currentIndex: Math.max(0, model.indexOf(page.sourceFilter)); onActivated: page.sourceFilter = currentText }
                        MbTextField { appTheme: page.appTheme; Layout.preferredWidth: 180; Layout.preferredHeight: 34; placeholderText: "搜索断点 / 命令 / 槽位"; text: page.searchText; onTextChanged: page.searchText = text }
                        Item { Layout.fillWidth: true }
                        MbButton { appTheme: page.appTheme; text: "新增"; iconText: "+"; enabled: false; variant: "primary"; implicitWidth: 76 }
                        MbButton { appTheme: page.appTheme; text: "启用"; variant: "success"; implicitWidth: 72; onClicked: page.setAllBreakpoints(true) }
                        MbButton { appTheme: page.appTheme; text: "禁用"; variant: "danger"; implicitWidth: 72; onClicked: page.setAllBreakpoints(false) }
                        MbButton { appTheme: page.appTheme; text: "刷新"; iconText: "↻"; variant: "neutral"; implicitWidth: 78; onClicked: bridge.refreshAll() }
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent ? parent.width : 900
                        spacing: 10
                        anchors.margins: 12

                        Repeater {
                            model: page.groups()
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                implicitHeight: groupLayout.implicitHeight
                                color: page.appTheme.panelBg
                                border.color: page.appTheme.border
                                radius: 4

                                ColumnLayout {
                                    id: groupLayout
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    spacing: 0

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        color: page.isExpanded(modelData.objectName) ? page.appTheme.panelActive : page.appTheme.panelBgAlt
                                        border.color: page.appTheme.border
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 12
                                            Text { text: page.isExpanded(modelData.objectName) ? "▾" : "▸"; color: page.appTheme.primary; font.pixelSize: 16; font.weight: Font.DemiBold }
                                            Text { text: modelData.objectName; color: page.appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.preferredWidth: 92; elide: Text.ElideRight }
                                            MbTag { appTheme: page.appTheme; text: "断点 " + modelData.rows.length; type: "primary"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "启用 " + modelData.enabledCount; type: "success"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "禁用 " + modelData.disabledCount; type: modelData.disabledCount > 0 ? "warning" : "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "命中 " + modelData.hitTotal; type: modelData.hitTotal > 0 ? "warning" : "neutral"; Layout.preferredWidth: 84 }
                                            Item { Layout.fillWidth: true }
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: page.setExpanded(modelData.objectName, !page.isExpanded(modelData.objectName)) }
                                    }

                                    ColumnLayout {
                                        visible: page.isExpanded(modelData.objectName)
                                        Layout.fillWidth: true
                                        Layout.margins: 12
                                        spacing: 8

                                        Repeater {
                                            model: modelData.rows
                                            delegate: Rectangle {
                                                required property var modelData
                                                property string idValue: page.itemId(modelData)
                                                Layout.fillWidth: true
                                                implicitHeight: 174
                                                radius: 4
                                                color: page.selectedBreakpointId === idValue ? page.appTheme.panelActive : page.appTheme.panelBgAlt
                                                border.color: page.selectedBreakpointId === idValue ? page.appTheme.primary : page.appTheme.border

                                                MouseArea { anchors.fill: parent; onClicked: page.selectedBreakpointId = idValue }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    spacing: 12

                                                    RowLayout {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        Layout.fillHeight: true
                                                        spacing: 12

                                                        ColumnLayout {
                                                            Layout.preferredWidth: 78
                                                            Layout.fillHeight: true
                                                            spacing: 8
                                                            MbSwitch { appTheme: page.appTheme; checked: !!modelData.enabled; Layout.alignment: Qt.AlignHCenter; onToggled: function(value) { bridge.setBreakpointEnabled(idValue, value) } }
                                                            MbTag { appTheme: page.appTheme; text: modelData.enabled ? "已启用" : "已禁用"; type: modelData.enabled ? "success" : "neutral"; Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 72 }
                                                        }

                                                        ColumnLayout {
                                                            Layout.fillWidth: true
                                                            Layout.minimumWidth: 0
                                                            Layout.fillHeight: true
                                                            spacing: 8
                                                            Text { text: modelData.name || (page.objectName(modelData) + " " + page.cmdName(modelData) + " breakpoint"); color: page.appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                            Text { text: page.objectName(modelData) + " / " + page.cmdName(modelData) + " / 槽位 " + page.slotText(modelData) + " / Session " + page.textOf(modelData.session_id || modelData.sessionId); color: page.appTheme.textNormal; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                            Text { text: "命中范围: " + page.rangeText(modelData); color: page.appTheme.textMuted; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        }
                                                    }

                                                    GridLayout {
                                                        Layout.preferredWidth: 240
                                                        Layout.minimumWidth: 240
                                                        Layout.fillHeight: true
                                                        columns: 2
                                                        rowSpacing: 8
                                                        columnSpacing: 8
                                                        MbTag { appTheme: page.appTheme; text: "匹配 " + page.matchModeText(modelData.match_mode); type: modelData.match_mode === "params_snapshot" ? "primary" : "neutral"; Layout.preferredWidth: 108 }
                                                        MbTag { appTheme: page.appTheme; text: "命中 " + (modelData.hit_count || 0); type: (modelData.hit_count || 0) > 0 ? "warning" : "neutral"; Layout.preferredWidth: 108 }
                                                        MbTag { appTheme: page.appTheme; text: page.sourceText(modelData); type: "neutral"; Layout.preferredWidth: 108 }
                                                        Text { text: page.shortTime(modelData.created_at || modelData.createdAt); color: page.appTheme.textMuted; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                    }

                                                    ColumnLayout {
                                                        Layout.preferredWidth: 150
                                                        Layout.minimumWidth: 150
                                                        Layout.fillHeight: true
                                                        spacing: 6
                                                        MbButton { appTheme: page.appTheme; text: "编辑条件"; enabled: false; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 30 }
                                                        MbButton { appTheme: page.appTheme; text: "命中记录"; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 30; onClicked: page.requestCallFilter(idValue) }
                                                        MbButton { appTheme: page.appTheme; text: "复制规则"; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 30; onClicked: bridge.copyText(page.jsonText(modelData)) }
                                                        MbButton { appTheme: page.appTheme; text: "删除"; variant: "danger"; Layout.fillWidth: true; Layout.preferredHeight: 30; onClicked: page.confirmDeleteBreakpoint(idValue, modelData.name || page.rangeText(modelData)) }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            visible: page.groups().length === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 260
                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Text { text: "暂无断点"; color: page.appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                Text { text: "可以从已发现接口或调用记录创建断点。"; color: page.appTheme.textMuted; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 420
            Layout.minimumWidth: 400
            Layout.maximumWidth: 420
            Layout.fillHeight: true
            color: appTheme.panelBg
            border.color: appTheme.border
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    color: appTheme.panelBg
                    border.color: appTheme.border
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "断点详情"; color: appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 0
                    TabButton { text: "概览"; selected: page.detailTabIndex === 0; Layout.preferredWidth: 80; onClicked: page.detailTabIndex = 0 }
                    TabButton { text: "匹配条件"; selected: page.detailTabIndex === 1; Layout.preferredWidth: 96; onClicked: page.detailTabIndex = 1 }
                    TabButton { text: "命中记录"; selected: page.detailTabIndex === 2; Layout.preferredWidth: 96; onClicked: page.detailTabIndex = 2 }
                    TabButton { text: "原始 JSON"; selected: page.detailTabIndex === 3; Layout.fillWidth: true; onClicked: page.detailTabIndex = 3 }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: page.detailTabIndex

                    ScrollView {
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        ColumnLayout {
                            x: 12
                            y: 12
                            width: Math.max(0, (parent ? parent.width : 400) - 24)
                            spacing: 10
                            MbDetailCard { appTheme: page.appTheme; title: "断点身份"; rows: page.overviewIdentityRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "状态与匹配"; rows: page.overviewStateRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "时间"; rows: page.overviewTimeRows(page.selectedItem) }
                        }
                    }
                    ScrollView {
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        ColumnLayout {
                            x: 12
                            y: 12
                            width: Math.max(0, (parent ? parent.width : 400) - 24)
                            spacing: 8
                            Repeater {
                                model: page.conditionLines(page.selectedItem)
                                delegate: Rectangle {
                                    id: conditionItem
                                    required property string modelData
                                    property bool expanded: false

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: conditionContent.implicitHeight + 20
                                    radius: 4
                                    color: page.appTheme.successSoft
                                    border.color: page.appTheme.border

                                    ColumnLayout {
                                        id: conditionContent
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: 10
                                        spacing: 6

                                        Text {
                                            id: conditionText
                                            text: conditionItem.modelData
                                            color: page.appTheme.textStrong
                                            font.pixelSize: 13
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 0
                                            wrapMode: conditionItem.expanded ? Text.Wrap : Text.NoWrap
                                            maximumLineCount: conditionItem.expanded ? 0 : 1
                                            elide: conditionItem.expanded ? Text.ElideNone : Text.ElideRight
                                        }

                                        Text {
                                            visible: conditionText.truncated || conditionItem.expanded
                                            text: conditionItem.expanded ? "收起" : "展开"
                                            color: page.appTheme.primary
                                            font.pixelSize: 12
                                            Layout.alignment: Qt.AlignRight
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: conditionText.truncated || conditionItem.expanded
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: conditionItem.expanded = !conditionItem.expanded
                                    }
                                }
                            }
                        }
                    }
                    ScrollView {
                        id: hitRecordScroll
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        contentWidth: availableWidth
                        contentHeight: hitRecordColumn.implicitHeight + 24
                        Column {
                            id: hitRecordColumn
                            x: 12
                            y: 12
                            width: Math.max(0, hitRecordScroll.availableWidth - 24)
                            spacing: 8
                            Repeater {
                                model: page.hitRecords(page.selectedItem)
                                delegate: Rectangle {
                                    required property var modelData
                                    width: hitRecordColumn.width
                                    height: 82
                                    radius: 4
                                    color: page.appTheme.panelBgAlt
                                    border.color: page.appTheme.borderSoft
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 6
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: "调用 #" + String(modelData.call_index || "-")
                                                color: page.appTheme.textStrong
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            MbTag { appTheme: page.appTheme; text: page.statusText(modelData.status); type: page.statusType(modelData.status); Layout.preferredWidth: 64 }
                                            Text {
                                                text: page.textOf(modelData.cost_ms) + " ms"
                                                color: page.appTheme.textStrong
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                        Text {
                                            text: page.objectName(modelData) + " / " + page.cmdName(modelData) + " / 槽位 " + page.slotText(modelData)
                                            color: page.appTheme.textNormal
                                            font.pixelSize: 12
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            text: page.shortTime(modelData.created_at)
                                            color: page.appTheme.textMuted
                                            font.pixelSize: 11
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                            Text {
                                visible: page.hitRecords(page.selectedItem).length === 0
                                width: hitRecordColumn.width
                                leftPadding: 12
                                topPadding: 12
                                text: "暂无命中记录"
                                color: page.appTheme.textMuted
                                font.pixelSize: 13
                            }
                        }
                    }
                    MbJsonViewer { appTheme: page.appTheme; text: page.jsonText(page.selectedItem || {}) }
                }
            }
        }
    }
}
