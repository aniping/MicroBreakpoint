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
    property string breakpointFilter: ""
    property string selectedCallId: ""
    property int detailTabIndex: 0
    property var expandedGroups: ({})
    property var groupSearches: ({})
    property var groupStatusFilters: ({})
    property var groupHitFilters: ({})
    property var groupSortKeys: ({})
    property var groupSortOrders: ({})
    property var columnWidths: [64, 170, 64, 240, 82, 76, 96, 96]
    property var columnMinWidths: [64, 120, 64, 240, 82, 76, 88, 88]
    property bool columnsWereResized: false
    property var selectedItem: selectedItemForId(selectedCallId)
    property var selectedDetail: selectedItem
    signal clearBreakpointFilterRequested()
    signal selectedCallChanged(string callId, string status)

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

    function callId(item) { return item ? String(item.call_id || item.callId || "") : "" }
    function rawArgs(item) { return safeObject(item ? (item.raw_args || item.rawArgs || {}) : {}, {}) }
    function objectName(item) {
        var args = rawArgs(item)
        return String((item && (item.object_name || item.objectName)) || args.objectName || "未分类")
    }
    function cmdName(item) {
        var args = rawArgs(item)
        return String((item && (item.cmd_name || item.cmdName || item.methodName || item.method_name)) || args.cmdName || "-")
    }
    function slotValue(item) {
        var args = rawArgs(item)
        var value = item ? (item.slot_id !== undefined ? item.slot_id : item.slotId) : undefined
        if (value === undefined || value === null) value = args.slotId
        return value === undefined || value === null || value === "" ? "-" : String(value)
    }
    function paramsSummary(item) {
        var value = item ? (item.params_summary || item.paramsSummary) : ""
        if (value) return String(value)
        return "-"
    }
    function resultSummary(item) {
        var value = item ? (item.result_summary || item.resultSummary) : ""
        return value ? String(value) : "-"
    }
    function sizeText(bytes) {
        var value = Number(bytes || 0)
        if (value >= 1024 * 1024) return (value / 1024 / 1024).toFixed(1) + "MB"
        if (value >= 1024) return (value / 1024).toFixed(1) + "KB"
        return value + "B"
    }
    function statusValue(item) {
        if (!item) return "-"
        if (item.status) return String(item.status)
        if (item.success === true) return "finished"
        if (item.success === false) return "exception"
        return "-"
    }
    function breakpointId(item) { return item ? String(item.breakpoint_id || item.breakpointId || "") : "" }
    function interfaceRegistered(item) {
        if (!item) return true
        if (item.interface_registered === 0 || item.interfaceRegistered === false) return false
        return true
    }
    function shortTime(value) {
        if (!value) return "-"
        return String(value).replace("T", " ").split("+")[0]
    }
    function costValue(item) {
        var value = item ? (item.cost_ms !== undefined ? item.cost_ms : item.costMs) : undefined
        return value === undefined || value === null ? "-" : String(value)
    }
    function statusText(status) {
        if (status === "running") return "运行中"
        if (status === "finished") return "成功"
        if (status === "paused") return "暂停"
        if (status === "imported_paused") return "历史暂停"
        if (status === "exception") return "异常"
        if (status === "continued") return "继续"
        if (status === "timeout") return "超时"
        return status || "-"
    }
    function statusType(status) {
        if (status === "finished") return "success"
        if (status === "paused" || status === "imported_paused" || status === "timeout") return "warning"
        if (status === "exception") return "danger"
        if (status === "running" || status === "continued") return "primary"
        return "neutral"
    }
    function statusColor(status) {
        if (statusType(status) === "success") return appTheme.success
        if (statusType(status) === "warning") return appTheme.warning
        if (statusType(status) === "danger") return appTheme.danger
        if (statusType(status) === "primary") return appTheme.primary
        return appTheme.textMuted
    }
    function textOf(value) {
        if (value === undefined || value === null || value === "") return "-"
        return String(value)
    }

    function breakpointSlotText(item) {
        if (!item) return "-"
        var value = item.slot_id !== undefined ? item.slot_id : item.slotId
        if (value === undefined || value === null || value === "") return "无槽位"
        return String(value)
    }

    function matchModeText(mode) {
        if (mode === "command_only") return "命令断点"
        if (mode === "params_snapshot" || mode === "params_condition") return "条件断点"
        return "命令断点"
    }

    function breakpointTitle(item) {
        if (!item) return "-"
        var name = item.name || ((item.object_name || item.objectName || "-") + " / " + (item.cmd_name || item.cmdName || "-"))
        if (String(name).toLowerCase().endsWith(" breakpoint")) name = String(name).slice(0, -11)
        return name
    }

    function breakpointSubtitle(item) {
        if (!item) return "-"
        var mode = item.match_mode || item.matchMode || "command_only"
        var text = (item.object_name || item.objectName || "-") + " / " + (item.cmd_name || item.cmdName || "-")
        if (mode !== "command_only") text += " / 槽位 " + breakpointSlotText(item) + " / " + matchModeText(mode)
        return text
    }

    function selectedItemForId(id) {
        if (items.length === 0) return null
        if (id) {
            for (var i = 0; i < items.length; i++) {
                if (callId(items[i]) === id) return items[i]
            }
        }
        return items[0]
    }

    function selectedPausedCount() {
        var count = 0
        for (var i = 0; i < items.length; i++) if (statusValue(items[i]) === "paused") count++
        return count
    }

    function ensureSelection() {
        if (items.length === 0) {
            selectedCallId = ""
            return
        }
        if (selectedCallId && selectedItemForId(selectedCallId) && callId(selectedItemForId(selectedCallId)) === selectedCallId) return
        for (var i = 0; i < items.length; i++) {
            if (statusValue(items[i]) === "paused") {
                selectedCallId = callId(items[i])
                return
            }
        }
        selectedCallId = callId(items[0])
    }

    function notifySelectedCallChanged() {
        selectedCallChanged(selectedCallId, statusValue(selectedItem))
    }

    onItemsChanged: Qt.callLater(function() {
        ensureSelection()
        selectedDetail = selectedCallId ? JSON.parse(bridge.callDetail(selectedCallId)) : selectedItem
        notifySelectedCallChanged()
    })
    onSelectedCallIdChanged: {
        detailTabIndex = 0
        selectedDetail = selectedCallId ? JSON.parse(bridge.callDetail(selectedCallId)) : selectedItem
        notifySelectedCallChanged()
    }

    function isExpanded(name) { return expandedGroups[name] !== false }
    function setExpanded(name, value) {
        var next = cloneObject(expandedGroups)
        next[name] = value
        expandedGroups = next
    }
    function setAllExpanded(value) {
        var next = {}
        var data = groups()
        for (var i = 0; i < data.length; i++) next[data[i].objectName] = value
        expandedGroups = next
    }
    function setGroupValue(store, groupName, value) {
        var next = cloneObject(store)
        next[groupName] = value
        return next
    }
    function groupSearch(name) { return groupSearches[name] || "" }
    function statusFilter(name) { return groupStatusFilters[name] || "全部" }
    function hitFilter(name) { return groupHitFilters[name] || "全部" }
    function sortKey(name) { return groupSortKeys[name] || "call_index" }
    function sortOrder(name) { return groupSortOrders[name] || "desc" }
    function setSort(name, key) {
        var nextKeys = cloneObject(groupSortKeys)
        var nextOrders = cloneObject(groupSortOrders)
        if ((nextKeys[name] || "call_index") === key) nextOrders[name] = (nextOrders[name] || "desc") === "asc" ? "desc" : "asc"
        else {
            nextKeys[name] = key
            nextOrders[name] = key === "call_index" || key === "created_at" || key === "cost_ms" || key === "hit" ? "desc" : "asc"
        }
        groupSortKeys = nextKeys
        groupSortOrders = nextOrders
    }
    function sortIndicator(name, key) {
        if (sortKey(name) !== key) return "◇"
        return sortOrder(name) === "asc" ? "▲" : "▼"
    }

    function groupRows(name) {
        var rows = []
        for (var i = 0; i < items.length; i++) {
            if (breakpointFilter && breakpointId(items[i]) !== breakpointFilter) continue
            if (objectName(items[i]) === name) rows.push(items[i])
        }
        return rows
    }

    function groups() {
        var byName = {}
        for (var i = 0; i < items.length; i++) {
            if (breakpointFilter && breakpointId(items[i]) !== breakpointFilter) continue
            var name = objectName(items[i])
            if (!byName[name]) byName[name] = {objectName: name, rows: [], hitCount: 0, pausedCount: 0, exceptionCount: 0, costTotal: 0, costCount: 0}
            var group = byName[name]
            group.rows.push(items[i])
            if (breakpointId(items[i])) group.hitCount++
            if (statusValue(items[i]) === "paused") group.pausedCount++
            if (statusValue(items[i]) === "exception") group.exceptionCount++
            var cost = Number(items[i].cost_ms !== undefined ? items[i].cost_ms : items[i].costMs)
            if (!isNaN(cost)) {
                group.costTotal += cost
                group.costCount++
            }
        }
        var result = []
        for (var key in byName) {
            byName[key].avgCost = byName[key].costCount > 0 ? Math.round(byName[key].costTotal / byName[key].costCount) : 0
            result.push(byName[key])
        }
        result.sort(function(a, b) { return a.objectName.localeCompare(b.objectName) })
        return result
    }

    function filteredRows(group) {
        var rows = group.rows.slice()
        var needle = groupSearch(group.objectName).toLowerCase()
        var state = statusFilter(group.objectName)
        var hit = hitFilter(group.objectName)
        var result = []
        for (var i = 0; i < rows.length; i++) {
            var item = rows[i]
            var haystack = (cmdName(item) + " " + paramsSummary(item) + " " + textOf(item.thread_name || item.threadName) + " " + textOf(item.interface_alias || item.interfaceAlias) + " " + callId(item)).toLowerCase()
            if (needle && haystack.indexOf(needle) < 0) continue
            if (state === "成功" && statusValue(item) !== "finished") continue
            if (state === "暂停" && statusValue(item) !== "paused") continue
            if (state === "异常" && statusValue(item) !== "exception") continue
            if (state === "运行中" && statusValue(item) !== "running") continue
            if (hit === "命中" && !breakpointId(item)) continue
            if (hit === "未命中" && breakpointId(item)) continue
            result.push(item)
        }
        var key = sortKey(group.objectName)
        var direction = sortOrder(group.objectName) === "asc" ? 1 : -1
        result.sort(function(a, b) {
            var av = sortValue(a, key)
            var bv = sortValue(b, key)
            if (typeof av === "number" && typeof bv === "number") return (av - bv) * direction
            return String(av).localeCompare(String(bv)) * direction
        })
        return result
    }

    function sortValue(item, key) {
        if (key === "call_index") return Number(item.call_index || item.callIndex || 0)
        if (key === "cmd_name") return cmdName(item)
        if (key === "slot_id") return Number(slotValue(item) === "-" ? -1 : slotValue(item))
        if (key === "status") return statusValue(item)
        if (key === "cost_ms") return Number(item.cost_ms || item.costMs || 0)
        if (key === "thread_name") return String(item.thread_name || item.threadName || "")
        if (key === "created_at") return String(item.created_at || item.createdAt || "")
        if (key === "interface_registered") return interfaceRegistered(item) ? 1 : 0
        if (key === "hit") return breakpointId(item) ? 1 : 0
        return ""
    }

    function isResizableColumn(index) {
        return index === 1 || index === 3
    }

    function storedColumnWidth(index) {
        return columnWidths[index] || columnMinWidths[index] || 80
    }

    function colWidth(index, tableWidth) {
        if (index === 3) {
            var available = Math.max(0, Number(tableWidth) || 0)
            var otherTotal = 0
            for (var i = 0; i < columnWidths.length; i++) {
                if (i !== 3) otherTotal += storedColumnWidth(i)
            }
            return Math.max(columnMinWidths[3], storedColumnWidth(3), available - otherTotal)
        }
        return storedColumnWidth(index)
    }

    function setColumnWidth(index, width) {
        if (!isResizableColumn(index)) return
        var next = columnWidths.slice()
        next[index] = Math.max(columnMinWidths[index] || 80, Math.min(520, width))
        columnWidths = next
        columnsWereResized = true
    }

    function totalColumnWidth(tableWidth) {
        var total = 0
        for (var i = 0; i < columnWidths.length; i++) total += colWidth(i, tableWidth)
        return total
    }

    function tableContentWidth(tableWidth) {
        var available = Math.max(0, Number(tableWidth) || 0)
        var total = totalColumnWidth(available)
        return columnsWereResized && total > available ? total : available
    }

    function tableHasHorizontalOverflow(tableWidth) {
        var available = Math.max(0, Number(tableWidth) || 0)
        return tableContentWidth(available) > available
    }

    function overviewRows(item) {
        return [
            ["callId", callId(item)],
            ["sessionId", textOf(item ? (item.session_id || item.sessionId) : "")],
            ["objectName", objectName(item)],
            ["cmdName", cmdName(item)],
            ["slotId", slotValue(item)],
            ["status", statusText(statusValue(item))],
            ["线程名", textOf(item ? (item.thread_name || item.threadName) : "")],
            ["调用时间", shortTime(item ? (item.created_at || item.createdAt) : "")],
            ["costMs", costValue(item)],
            ["命中断点", breakpointId(item) ? "是" : "否"],
            ["breakpointId", breakpointId(item) || "-"]
        ]
    }

    function payloadRows(item) {
        return [
            ["paramsSize", sizeText(item ? (item.params_size || item.paramsSize || 0) : 0)],
            ["paramsHash", textOf(item ? (item.params_hash || item.paramsHash || item.params_fingerprint || item.paramsFingerprint) : "")],
            ["paramsPreview", textOf(item ? (item.params_preview || item.paramsPreview || item.params_summary || item.paramsSummary) : "")],
            ["resultSize", sizeText(item ? (item.result_size || item.resultSize || 0) : 0)],
            ["resultHash", textOf(item ? (item.result_hash || item.resultHash) : "")],
            ["resultPreview", textOf(item ? (item.result_preview || item.resultPreview || item.result_summary || item.resultSummary) : "")]
        ]
    }

    function overviewBasicRows(item) {
        return [
            ["callId", callId(item)],
            ["sessionId", textOf(item ? (item.session_id || item.sessionId) : "")],
            ["objectName", objectName(item)],
            ["cmdName", cmdName(item)],
            ["slotId", slotValue(item)]
        ]
    }

    function overviewStateRows(item) {
        return [
            ["状态", statusText(statusValue(item))],
            ["耗时", costValue(item) + " ms"],
            ["接口登记", interfaceRegistered(item) ? "已登记" : "未登记"],
            ["命中断点", breakpointId(item) ? "是" : "否"],
            ["breakpointId", breakpointId(item) || "-"]
        ]
    }

    function overviewTimeRows(item) {
        return [
            ["线程名", textOf(item ? (item.thread_name || item.threadName) : "")],
            ["调用时间", shortTime(item ? (item.created_at || item.createdAt) : "")]
        ]
    }

    function confirmClearRecords() {
        confirmDialog.ask("清空当前会话", "确认清空当前会话的数据吗？该操作会删除当前会话的接口、调用记录和相关断点。", "清空", function() {
            bridge.clearCalls()
        })
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
        property string prefix: ""
        implicitHeight: 34
        padding: 0
        font.pixelSize: 13
        background: Rectangle {
            radius: 4
            color: combo.pressed ? page.appTheme.panelHover : page.appTheme.inputBg
            border.color: combo.visualFocus ? page.appTheme.primary : page.appTheme.border
        }
        contentItem: Text {
            text: combo.prefix + combo.displayText
            color: page.appTheme.textNormal
            font: combo.font
            verticalAlignment: Text.AlignVCenter
            leftPadding: 10
            rightPadding: 26
            elide: Text.ElideRight
        }
        indicator: Text {
            text: "⌄"
            color: page.appTheme.textMuted
            font.pixelSize: 13
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 8
        }
    }

    component HeaderCell: Rectangle {
        id: header
        property int column: 0
        property real tableWidth: 0
        property string groupName: ""
        property string label: ""
        property string sortField: ""
        property bool sortable: true
        property bool resizable: page.isResizableColumn(column)
        width: page.colWidth(column, tableWidth)
        height: 36
        color: page.appTheme.panelBgAlt
        border.color: page.appTheme.border

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: header.resizable ? 18 : 10
            text: header.label + (header.sortable ? " " + page.sortIndicator(header.groupName, header.sortField) : "")
            color: page.appTheme.textStrong
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        MouseArea {
            anchors.fill: parent
            anchors.rightMargin: header.resizable ? 10 : 0
            enabled: header.sortable
            cursorShape: header.sortable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: page.setSort(header.groupName, header.sortField)
        }

        Rectangle {
            visible: header.resizable
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 12
            color: resizeArea.pressed || resizeArea.containsMouse ? page.appTheme.primarySoft : "transparent"
            border.color: resizeArea.pressed || resizeArea.containsMouse ? page.appTheme.primary : "transparent"
            MouseArea {
                id: resizeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SizeHorCursor
                property real startX: 0
                property real startWidth: 0
                onPressed: function(mouse) {
                    startX = mouse.x
                    startWidth = page.colWidth(header.column, header.tableWidth)
                }
                onPositionChanged: function(mouse) {
                    if (pressed) page.setColumnWidth(header.column, startWidth + mouse.x - startX)
                }
            }
        }
    }

    component DataCell: Rectangle {
        property string label: ""
        property color labelColor: page.appTheme.textNormal
        property int column: 0
        property real tableWidth: 0
        width: page.colWidth(column, tableWidth)
        height: 38
        color: "transparent"
        border.color: page.appTheme.borderSoft
        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 10
            anchors.rightMargin: 8
            text: parent.label
            color: parent.labelColor
            font.pixelSize: 13
            elide: Text.ElideRight
        }
    }

    component StatusBadge: Rectangle {
        property string value: ""
        width: 56
        height: 24
        radius: 4
        color: page.statusType(value) === "success" ? page.appTheme.successSoft
              : page.statusType(value) === "warning" ? page.appTheme.warningSoft
              : page.statusType(value) === "danger" ? page.appTheme.dangerSoft
              : page.statusType(value) === "primary" ? page.appTheme.primarySoft
              : page.appTheme.panelBgAlt
        border.color: page.statusColor(value)
        Text {
            anchors.centerIn: parent
            text: page.statusText(parent.value)
            color: page.statusColor(parent.value)
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
    }

    component MiniTag: Rectangle {
        id: miniTag
        property string text: ""
        property string type: "neutral"
        height: 17
        radius: 4
        color: miniTag.type === "warning" ? page.appTheme.warningSoft
              : miniTag.type === "danger" ? page.appTheme.dangerSoft
              : miniTag.type === "success" ? page.appTheme.successSoft
              : page.appTheme.panelBgAlt
        border.color: miniTag.type === "warning" ? page.appTheme.warning
                    : miniTag.type === "danger" ? page.appTheme.danger
                    : miniTag.type === "success" ? page.appTheme.success
                    : page.appTheme.textDisabled
        Text {
            anchors.centerIn: parent
            text: miniTag.text
            color: miniTag.border.color
            font.pixelSize: 10
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    component TagCell: Rectangle {
        property int column: 0
        property string label: ""
        property string type: "neutral"
        property real tableWidth: 0
        width: page.colWidth(column, tableWidth)
        height: 38
        color: "transparent"
        border.color: page.appTheme.borderSoft
        MiniTag {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 12)
            height: 20
            text: parent.label
            type: parent.type
        }
    }

    component TabButton: Button {
        id: tab
        property bool selected: false
        implicitHeight: 38
        padding: 0
        background: Rectangle {
            color: tab.selected ? page.appTheme.primary : (tab.hovered ? page.appTheme.panelHover : page.appTheme.panelBgAlt)
            border.color: tab.selected ? page.appTheme.primary : page.appTheme.border
        }
        contentItem: Text {
            text: tab.text
            color: tab.selected ? page.appTheme.onAccent : page.appTheme.textNormal
            font.pixelSize: 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
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
                    Layout.preferredHeight: 54
                    color: appTheme.panelBg
                    border.color: appTheme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 10
                        Text {
                            text: "调用记录"
                            color: appTheme.textStrong
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                        }
                        MbTag {
                            visible: page.breakpointFilter.length > 0
                            appTheme: page.appTheme
                            text: "断点过滤"
                            type: "warning"
                        }
                        MbButton {
                            visible: page.breakpointFilter.length > 0
                            appTheme: page.appTheme
                            text: "清除过滤"
                            variant: "neutral"
                            implicitWidth: 92
                            onClicked: page.clearBreakpointFilterRequested()
                        }
                        Item { Layout.fillWidth: true }
                        MbButton { appTheme: page.appTheme; text: "全部展开"; iconText: "⌄"; variant: "neutral"; implicitWidth: 104; onClicked: page.setAllExpanded(true) }
                        MbButton { appTheme: page.appTheme; text: "全部收起"; iconText: "⌃"; variant: "neutral"; implicitWidth: 104; onClicked: page.setAllExpanded(false) }
                        MbButton { appTheme: page.appTheme; text: "刷新"; iconText: "↻"; variant: "neutral"; implicitWidth: 88; onClicked: bridge.refreshAll() }
                        MbButton { appTheme: page.appTheme; text: "清空记录"; iconText: "×"; variant: "danger"; implicitWidth: 104; enabled: page.canClearRecords && items.length > 0; onClicked: page.confirmClearRecords() }
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
                                radius: 4
                                color: page.appTheme.panelBg
                                border.color: page.appTheme.border

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
                                            Text {
                                                text: page.isExpanded(modelData.objectName) ? "▾" : "▸"
                                                color: page.appTheme.primary
                                                font.pixelSize: 16
                                                font.weight: Font.DemiBold
                                            }
                                            Text {
                                                text: modelData.objectName
                                                color: page.appTheme.textStrong
                                                font.pixelSize: 15
                                                font.weight: Font.DemiBold
                                                Layout.preferredWidth: 92
                                                elide: Text.ElideRight
                                            }
                                            MbTag { appTheme: page.appTheme; text: "调用 " + modelData.rows.length; type: "primary"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "命中 " + modelData.hitCount; type: modelData.hitCount > 0 ? "warning" : "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "暂停 " + modelData.pausedCount; type: modelData.pausedCount > 0 ? "warning" : "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "异常 " + modelData.exceptionCount; type: modelData.exceptionCount > 0 ? "danger" : "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "平均耗时 " + modelData.avgCost + " ms"; type: "neutral"; Layout.preferredWidth: 140 }
                                            Item { Layout.fillWidth: true }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            onClicked: page.setExpanded(modelData.objectName, !page.isExpanded(modelData.objectName))
                                        }
                                    }

                                    ColumnLayout {
                                        visible: page.isExpanded(modelData.objectName)
                                        Layout.fillWidth: true
                                        Layout.leftMargin: 12
                                        Layout.rightMargin: 12
                                        Layout.topMargin: 10
                                        Layout.bottomMargin: 10
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            MbTextField {
                                                appTheme: page.appTheme
                                                Layout.preferredWidth: 330
                                                Layout.maximumWidth: 360
                                                Layout.preferredHeight: 34
                                                placeholderText: "搜索 " + modelData.objectName + " 内调用（命令 / 参数 / 线程名）"
                                                text: page.groupSearch(modelData.objectName)
                                                onTextChanged: {
                                                    page.groupSearches = page.setGroupValue(page.groupSearches, modelData.objectName, text)
                                                }
                                            }
                                            FilterCombo {
                                                Layout.preferredWidth: 120
                                                model: ["全部", "成功", "暂停", "异常", "运行中"]
                                                currentIndex: Math.max(0, model.indexOf(page.statusFilter(modelData.objectName)))
                                                prefix: "状态: "
                                                onActivated: page.groupStatusFilters = page.setGroupValue(page.groupStatusFilters, modelData.objectName, currentText)
                                            }
                                            FilterCombo {
                                                Layout.preferredWidth: 140
                                                model: ["全部", "命中", "未命中"]
                                                currentIndex: Math.max(0, model.indexOf(page.hitFilter(modelData.objectName)))
                                                prefix: "命中断点: "
                                                onActivated: page.groupHitFilters = page.setGroupValue(page.groupHitFilters, modelData.objectName, currentText)
                                            }
                                            Item { Layout.fillWidth: true }
                                            MbButton { appTheme: page.appTheme; text: "重置"; variant: "neutral"; implicitWidth: 74; onClicked: {
                                                page.groupSearches = page.setGroupValue(page.groupSearches, modelData.objectName, "")
                                                page.groupStatusFilters = page.setGroupValue(page.groupStatusFilters, modelData.objectName, "全部")
                                                page.groupHitFilters = page.setGroupValue(page.groupHitFilters, modelData.objectName, "全部")
                                            } }
                                        }

                                        Flickable {
                                            id: tableFlick
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: tableContent.implicitHeight + (page.tableHasHorizontalOverflow(tableFlick.width) ? 14 : 0)
                                            clip: true
                                            contentWidth: page.tableContentWidth(tableFlick.width)
                                            contentHeight: tableContent.implicitHeight
                                            flickableDirection: Flickable.HorizontalFlick
                                            boundsBehavior: Flickable.StopAtBounds
                                            interactive: false
                                            ScrollBar.horizontal: ScrollBar {
                                                policy: page.tableHasHorizontalOverflow(tableFlick.width) ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                                interactive: page.tableHasHorizontalOverflow(tableFlick.width)
                                                contentItem: Rectangle { implicitHeight: 8; radius: 4; color: parent.pressed ? page.appTheme.primary : page.appTheme.textDisabled }
                                                background: Rectangle { color: page.appTheme.panelBgAlt; radius: 4 }
                                            }

                                            Column {
                                                id: tableContent
                                                width: page.tableContentWidth(tableFlick.width)
                                                Row {
                                                    HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName; column: 0; label: "序号"; sortField: "call_index" }
                                                    HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName; column: 1; label: "命令"; sortField: "cmd_name" }
                                                    HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName; column: 2; label: "槽位"; sortField: "slot_id" }
                                                    HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName; column: 3; label: "参数摘要"; sortField: "params"; sortable: false }
                                                    HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName; column: 4; label: "状态"; sortField: "status" }
                                                    HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName; column: 5; label: "耗时"; sortField: "cost_ms" }
                                                    HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName; column: 6; label: "断点"; sortField: "hit" }
                                                    HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName; column: 7; label: "接口"; sortField: "interface_registered" }
                                                }
                                                Repeater {
                                                    model: page.filteredRows(modelData)
                                                    delegate: Rectangle {
                                                        required property var modelData
                                                        width: tableContent.width
                                                        height: 38
                                                        color: page.selectedCallId === page.callId(modelData)
                                                               ? page.appTheme.panelActive
                                                               : (page.statusType(page.statusValue(modelData)) === "warning" ? page.appTheme.warningSoft : "transparent")
                                                        Row {
                                                            anchors.fill: parent
                                                            DataCell { tableWidth: tableFlick.width; column: 0; label: String(modelData.call_index || modelData.callIndex || "") }
                                                            DataCell { tableWidth: tableFlick.width; column: 1; label: page.cmdName(modelData); labelColor: page.appTheme.textStrong }
                                                            DataCell { tableWidth: tableFlick.width; column: 2; label: page.slotValue(modelData) }
                                                            DataCell { tableWidth: tableFlick.width; column: 3; label: page.paramsSummary(modelData) }
                                                            Rectangle {
                                                                width: page.colWidth(4, tableFlick.width)
                                                                height: 38
                                                                color: "transparent"
                                                                border.color: page.appTheme.borderSoft
                                                                StatusBadge { value: page.statusValue(modelData); anchors.centerIn: parent }
                                                            }
                                                            DataCell { tableWidth: tableFlick.width; column: 5; label: page.costValue(modelData) }
                                                            TagCell {
                                                                tableWidth: tableFlick.width
                                                                column: 6
                                                                label: page.breakpointId(modelData) ? "已命中" : "未命中"
                                                                type: page.breakpointId(modelData) ? "warning" : "neutral"
                                                            }
                                                            TagCell {
                                                                tableWidth: tableFlick.width
                                                                column: 7
                                                                label: page.interfaceRegistered(modelData) ? "已登记" : "未登记"
                                                                type: page.interfaceRegistered(modelData) ? "success" : "danger"
                                                            }
                                                        }
                                                        MouseArea {
                                                            anchors.fill: parent
                                                            onClicked: {
                                                                page.selectedCallId = page.callId(modelData)
                                                                page.detailTabIndex = 0
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 34
                                            color: page.appTheme.panelBgAlt
                                            border.color: page.appTheme.borderSoft
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.leftMargin: 12
                                                anchors.rightMargin: 12
                                                text: "当前分组显示 " + page.filteredRows(modelData).length + " / 总数 " + modelData.rows.length + " 条"
                                                color: page.appTheme.textNormal
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
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
                                Text { text: "暂无调用记录"; color: page.appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                Text { text: "开始调试后，外部 Java 请求会显示在这里。"; color: page.appTheme.textMuted; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    color: appTheme.panelBgAlt
                    border.color: appTheme.border
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        text: "共 " + page.groups().length + " 组，" + items.length + " 条调用记录"
                        color: appTheme.textNormal
                        font.pixelSize: 13
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
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 8
                        Text {
                            text: "调用详情"
                            color: appTheme.textStrong
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        MbButton {
                            appTheme: page.appTheme
                            text: "刷新"
                            variant: "neutral"
                            implicitWidth: 72
                            Layout.preferredHeight: 34
                            onClicked: bridge.refreshAll()
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 0
                    TabButton { text: "概览"; selected: page.detailTabIndex === 0; Layout.preferredWidth: 64; onClicked: page.detailTabIndex = 0 }
                    TabButton { text: "入参"; selected: page.detailTabIndex === 1; Layout.preferredWidth: 70; onClicked: page.detailTabIndex = 1 }
                    TabButton { text: "返回"; selected: page.detailTabIndex === 2; Layout.preferredWidth: 70; onClicked: page.detailTabIndex = 2 }
                    TabButton { text: "Payload"; selected: page.detailTabIndex === 3; Layout.preferredWidth: 70; onClicked: page.detailTabIndex = 3 }
                    TabButton { text: "技术信息"; selected: page.detailTabIndex === 4; Layout.preferredWidth: 70; onClicked: page.detailTabIndex = 4 }
                    TabButton { text: "原始 JSON"; selected: page.detailTabIndex === 5; Layout.fillWidth: true; onClicked: page.detailTabIndex = 5 }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: page.detailTabIndex

                    ScrollView {
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                            contentItem: Rectangle { implicitWidth: 8; radius: 4; color: parent.pressed ? page.appTheme.primary : page.appTheme.textDisabled }
                            background: Rectangle { color: "transparent" }
                        }
                        ColumnLayout {
                            x: 12
                            y: 12
                            width: Math.max(0, (parent ? parent.width : 380) - 24)
                            spacing: 10
                            MbDetailCard { appTheme: page.appTheme; title: "基础信息"; rows: page.overviewBasicRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "执行状态"; rows: page.overviewStateRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "线程与时间"; rows: page.overviewTimeRows(page.selectedItem) }
                        }
                    }
                    LargePayloadViewer {
                        appTheme: page.appTheme
                        callId: page.callId(page.selectedDetail)
                        payloadType: "params"
                        title: "入参 params"
                        preview: page.selectedDetail ? (page.selectedDetail.params_preview || page.selectedDetail.paramsPreview || "") : ""
                        payloadSize: page.selectedDetail ? Number(page.selectedDetail.params_size || page.selectedDetail.paramsSize || 0) : 0
                        payloadHash: page.selectedDetail ? String(page.selectedDetail.params_hash || page.selectedDetail.paramsHash || page.selectedDetail.params_fingerprint || page.selectedDetail.paramsFingerprint || "") : ""
                        truncated: page.selectedDetail ? !!(page.selectedDetail.params_truncated || page.selectedDetail.paramsTruncated) : false
                    }
                    LargePayloadViewer {
                        appTheme: page.appTheme
                        callId: page.callId(page.selectedDetail)
                        payloadType: "result"
                        title: "返回 result"
                        preview: page.selectedDetail ? (page.selectedDetail.result_preview || page.selectedDetail.resultPreview || "") : ""
                        payloadSize: page.selectedDetail ? Number(page.selectedDetail.result_size || page.selectedDetail.resultSize || 0) : 0
                        payloadHash: page.selectedDetail ? String(page.selectedDetail.result_hash || page.selectedDetail.resultHash || "") : ""
                        truncated: page.selectedDetail ? !!(page.selectedDetail.result_truncated || page.selectedDetail.resultTruncated) : false
                    }
                    ScrollView {
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AlwaysOff
                        }
                        ColumnLayout {
                            x: 12
                            y: 12
                            width: Math.max(0, (parent ? parent.width : 380) - 24)
                            spacing: 10
                            MbDetailCard { appTheme: page.appTheme; title: "Payload 摘要"; rows: page.payloadRows(page.selectedDetail) }
                        }
                    }
                    MbJsonViewer { appTheme: page.appTheme; text: page.jsonText({
                        serviceName: page.selectedItem ? (page.selectedItem.service_name || page.selectedItem.serviceName) : "",
                        className: page.selectedItem ? (page.selectedItem.class_name || page.selectedItem.className) : "",
                        methodName: page.selectedItem ? (page.selectedItem.method_name || page.selectedItem.methodName) : "",
                        displayName: page.selectedItem ? (page.selectedItem.display_name || page.selectedItem.displayName) : "",
                        parameterMeta: page.selectedItem ? (page.selectedItem.parameter_meta || page.selectedItem.parameterMeta || []) : [],
                        exceptionType: page.selectedItem ? (page.selectedItem.exception_type || page.selectedItem.exceptionType) : "",
                        exceptionMessage: page.selectedItem ? (page.selectedItem.exception_message || page.selectedItem.exceptionMessage) : ""
                    }) }
                    MbJsonViewer { appTheme: page.appTheme; text: page.jsonText(page.selectedItem ? {
                        callId: page.callId(page.selectedItem),
                        objectName: page.objectName(page.selectedItem),
                        cmdName: page.cmdName(page.selectedItem),
                        slotId: page.slotValue(page.selectedItem),
                        status: page.statusValue(page.selectedItem),
                        paramsSummary: page.paramsSummary(page.selectedItem),
                        resultSummary: page.resultSummary(page.selectedItem)
                    } : {}) }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 190
                    color: appTheme.panelBg
                    border.color: appTheme.border
                    GridLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        columns: 2
                        rowSpacing: 8
                        columnSpacing: 10
                        MbButton { appTheme: page.appTheme; text: "继续执行"; iconText: "▶"; enabled: page.selectedItem && page.statusValue(page.selectedItem) === "paused"; variant: "primary"; Layout.fillWidth: true; Layout.preferredHeight: 36; onClicked: bridge.continueCall(page.callId(page.selectedItem)) }
                        MbButton { appTheme: page.appTheme; text: "继续全部"; iconText: "▶"; enabled: page.selectedPausedCount() > 0; variant: page.selectedPausedCount() > 0 ? "success" : "primary"; Layout.fillWidth: true; Layout.preferredHeight: 36; onClicked: bridge.continueAll() }
                        MbButton { appTheme: page.appTheme; text: "命令断点"; enabled: page.selectedItem !== null; variant: "primary"; Layout.fillWidth: true; Layout.preferredHeight: 36; onClicked: bridge.createMethodBreakpointFromCall(page.callId(page.selectedItem)) }
                        MbButton { appTheme: page.appTheme; text: "创建条件断点"; enabled: page.selectedItem !== null; variant: "primary"; Layout.fillWidth: true; Layout.preferredHeight: 36; onClicked: bridge.createBreakpointFromCall(page.callId(page.selectedItem)) }
                        MbButton { appTheme: page.appTheme; text: page.interfaceRegistered(page.selectedItem) ? "已登记接口" : "加入接口列表"; enabled: page.selectedItem !== null && !page.interfaceRegistered(page.selectedItem); variant: page.interfaceRegistered(page.selectedItem) ? "neutral" : "primary"; Layout.fillWidth: true; Layout.preferredHeight: 36; onClicked: bridge.addInterfaceFromCall(page.callId(page.selectedItem)) }
                        MbButton { appTheme: page.appTheme; text: "导出参数"; enabled: page.selectedItem !== null; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 36; onClicked: bridge.exportPayload(page.callId(page.selectedItem), "params") }
                        MbButton { appTheme: page.appTheme; text: "导出返回"; enabled: page.selectedItem !== null; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 36; onClicked: bridge.exportPayload(page.callId(page.selectedItem), "result") }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    color: appTheme.panelBgAlt
                    border.color: appTheme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 12
                        spacing: 8
                        Text {
                            text: "断点列表 (" + breakpoints.length + ")"
                            color: appTheme.textStrong
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        Text {
                            text: "当前 Session"
                            color: appTheme.textMuted
                            font.pixelSize: 12
                        }
                    }
                }

                ListView {
                    id: breakpointList
                    Layout.fillWidth: true
                    Layout.preferredHeight: 174
                    visible: true
                    model: breakpoints
                    clip: true
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: breakpointList.width
                        height: 58
                        color: index % 2 ? page.appTheme.panelBgAlt : page.appTheme.panelBg
                        border.color: page.appTheme.borderSoft
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10
                            Rectangle { Layout.preferredWidth: 9; Layout.preferredHeight: 9; radius: 5; color: modelData.enabled ? page.appTheme.success : page.appTheme.textDisabled }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                                spacing: 2
                                Text { text: page.breakpointTitle(modelData); color: page.appTheme.textStrong; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                Text { text: page.breakpointSubtitle(modelData) + " / 命中 " + page.textOf(modelData.hit_count || modelData.hitCount || 0); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                            }
                            Text { text: modelData.enabled ? "开" : "关"; color: modelData.enabled ? page.appTheme.success : page.appTheme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 18 }
                            MbSwitch {
                                appTheme: page.appTheme
                                checked: !!modelData.enabled
                                onToggled: function(value) { bridge.setBreakpointEnabled(modelData.id, value) }
                            }
                            MbButton {
                                appTheme: page.appTheme
                                text: "×"
                                variant: "danger"
                                Layout.preferredWidth: 32
                                Layout.preferredHeight: 28
                                onClicked: page.confirmDeleteBreakpoint(modelData.id, page.breakpointTitle(modelData))
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: breakpoints.length === 0
                        text: "暂无断点"
                        color: page.appTheme.textMuted
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
