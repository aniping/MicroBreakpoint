import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Item {
    id: page

    property var appTheme
    property var items: []
    property var calls: []
    property var breakpoints: []
    property string selectedInterfaceId: ""
    property int detailTabIndex: 0
    property int selectedSampleIndex: 0
    property bool onlyWithBreakpoints: false
    property var expandedGroups: ({})
    property var groupSearches: ({})
    property var groupSorts: ({})
    property var selectedItem: selectedItemForId(selectedInterfaceId)

    function cloneObject(value) {
        var next = {}
        for (var key in (value || {})) next[key] = value[key]
        return next
    }
    function setStoreValue(store, key, value) {
        var next = cloneObject(store)
        next[key] = value
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
    function itemId(item) { return item ? String(item.id || item.interface_id || item.interfaceId || "") : "" }
    function callId(item) { return item ? String(item.call_id || item.callId || "") : "" }
    function objectName(item) { return String(item ? (item.object_name || item.objectName || "未分类") : "未分类") }
    function cmdName(item) { return String(item ? (item.cmd_name || item.cmdName || item.method_name || item.methodName || "-") : "-") }
    function slotText(item) {
        var value = item ? (item.slot_id !== undefined ? item.slot_id : item.slotId) : undefined
        return value === undefined || value === null || value === "" ? "无槽位" : String(value)
    }
    function latestParams(item) {
        return safeObject(item ? (item.latest_params || item.latestParams || item.latest_params_json || item.sample_args || item.sample_args_json || {}) : {}, {})
    }
    function callParams(item) {
        return safeObject(item ? (item.params || item.params_json || {}) : {}, {})
    }
    function paramsSummary(item) {
        var summary = item ? (item.params_summary || item.paramsSummary) : ""
        if (summary) return String(summary)
        return jsonText(latestParams(item)).replace(/\s+/g, " ")
    }
    function shortTime(value) {
        if (!value) return "-"
        return String(value).replace("T", " ").split("+")[0]
    }
    function roundNumber(value) {
        var number = Number(value || 0)
        return isNaN(number) ? 0 : Math.round(number)
    }
    function avgCostText(item) {
        return String(roundNumber(item ? (item.avg_cost_ms || item.avgCostMs || 0) : 0))
    }
    function sampleCount(item) {
        return Number(item ? (item.params_sample_count || item.paramsSampleCount || 0) : 0)
    }
    function fingerprint(item) {
        var fp = item ? (item.latest_params_fingerprint || item.params_fingerprint || item.paramsFingerprint || "") : ""
        if (fp) return String(fp)
        var text = jsonText(latestParams(item))
        var hash = 0
        for (var i = 0; i < text.length; i++) hash = ((hash << 5) - hash + text.charCodeAt(i)) | 0
        return Math.abs(hash).toString(16)
    }
    function shortFingerprint(value) {
        var text = String(value || "")
        return text.length > 12 ? text.slice(0, 12) : text
    }
    function uniqueKey(item) {
        return cmdName(item) + " / " + slotText(item) + " / " + shortFingerprint(fingerprint(item))
    }
    function interfaceBreakpoints(item) {
        var result = []
        if (!item) return result
        for (var i = 0; i < breakpoints.length; i++) {
            var bp = breakpoints[i]
            var sameSource = String(bp.source_interface_id || bp.sourceInterfaceId || "") === itemId(item)
            var sameMatch = objectName(bp) === objectName(item) && cmdName(bp) === cmdName(item) && slotText(bp) === slotText(item)
            if (sameSource || sameMatch) result.push(bp)
        }
        return result
    }
    function interfaceBreakpoint(interfaceId) {
        for (var i = 0; i < items.length; i++) {
            if (itemId(items[i]) === String(interfaceId)) {
                var rows = interfaceBreakpoints(items[i])
                return rows.length > 0 ? rows[0] : null
            }
        }
        return null
    }
    function enabledBreakpointCount(item) {
        var rows = interfaceBreakpoints(item)
        var count = 0
        for (var i = 0; i < rows.length; i++) if (rows[i].enabled) count++
        return count
    }
    function hasBreakpoint(item) {
        return interfaceBreakpoints(item).length > 0
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
            selectedInterfaceId = ""
            selectedSampleIndex = 0
            return
        }
        if (selectedInterfaceId && selectedItemForId(selectedInterfaceId) && itemId(selectedItemForId(selectedInterfaceId)) === selectedInterfaceId) return
        selectedInterfaceId = itemId(items[0])
    }
    onItemsChanged: Qt.callLater(ensureSelection)
    onSelectedInterfaceIdChanged: selectedSampleIndex = 0

    function isExpanded(name) { return expandedGroups[name] !== false }
    function setExpanded(name, value) { expandedGroups = setStoreValue(expandedGroups, name, value) }
    function setAllExpanded(value) {
        var next = {}
        var data = groups()
        for (var i = 0; i < data.length; i++) next[data[i].objectName] = value
        expandedGroups = next
    }
    function groupSearch(name) { return groupSearches[name] || "" }
    function groupSort(name) { return groupSorts[name] || "最近调用" }

    function groups() {
        var map = {}
        for (var i = 0; i < items.length; i++) {
            if (onlyWithBreakpoints && !hasBreakpoint(items[i])) continue
            var name = objectName(items[i])
            if (!map[name]) map[name] = {objectName: name, rows: [], callCount: 0, sampleCount: 0, exceptionCount: 0, enabledBreakpointCount: 0}
            var group = map[name]
            group.rows.push(items[i])
            group.callCount += Number(items[i].call_count || items[i].callCount || 0)
            group.sampleCount += sampleCount(items[i])
            group.exceptionCount += Number(items[i].exception_count || items[i].exceptionCount || 0)
            group.enabledBreakpointCount += enabledBreakpointCount(items[i])
        }
        var result = []
        for (var key in map) result.push(map[key])
        result.sort(function(a, b) { return a.objectName.localeCompare(b.objectName) })
        return result
    }

    function filteredRows(group) {
        var rows = group.rows.slice()
        var needle = groupSearch(group.objectName).toLowerCase()
        var result = []
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i]
            var haystack = (cmdName(row) + " " + slotText(row) + " " + paramsSummary(row) + " " + uniqueKey(row)).toLowerCase()
            if (needle && haystack.indexOf(needle) < 0) continue
            result.push(row)
        }
        var sort = groupSort(group.objectName)
        result.sort(function(a, b) {
            if (sort === "调用次数") return Number(b.call_count || 0) - Number(a.call_count || 0)
            if (sort === "平均耗时") return Number(b.avg_cost_ms || 0) - Number(a.avg_cost_ms || 0)
            if (sort === "异常数量") return Number(b.exception_count || 0) - Number(a.exception_count || 0)
            if (sort === "命令名称") return cmdName(a).localeCompare(cmdName(b))
            return String(b.last_seen_at || b.updated_at || "").localeCompare(String(a.last_seen_at || a.updated_at || ""))
        })
        return result
    }

    function relatedCalls(item) {
        var result = []
        if (!item) return result
        for (var i = 0; i < calls.length; i++) {
            if (objectName(calls[i]) === objectName(item) && cmdName(calls[i]) === cmdName(item) && slotText(calls[i]) === slotText(item)) result.push(calls[i])
        }
        result.sort(function(a, b) { return Number(b.call_index || b.callIndex || 0) - Number(a.call_index || a.callIndex || 0) })
        return result
    }

    function sampleRows(item) {
        var rows = relatedCalls(item)
        var byFingerprint = {}
        var result = []
        for (var i = 0; i < rows.length; i++) {
            var call = rows[i]
            var fp = String(call.params_fingerprint || call.paramsFingerprint || "")
            if (!fp) {
                var text = jsonText(callParams(call))
                var hash = 0
                for (var j = 0; j < text.length; j++) hash = ((hash << 5) - hash + text.charCodeAt(j)) | 0
                fp = Math.abs(hash).toString(16)
            }
            if (!byFingerprint[fp]) {
                byFingerprint[fp] = {
                    fingerprint: fp,
                    callId: callId(call),
                    params: callParams(call),
                    paramsSummary: call.params_summary || call.paramsSummary || paramsSummary(call),
                    firstSeenAt: call.created_at || call.createdAt || "",
                    lastSeenAt: call.created_at || call.createdAt || "",
                    seenCount: 1,
                    status: call.status || "",
                    costMs: call.cost_ms !== undefined ? call.cost_ms : call.costMs
                }
                result.push(byFingerprint[fp])
            } else {
                byFingerprint[fp].seenCount += 1
                var time = call.created_at || call.createdAt || ""
                if (String(time) > String(byFingerprint[fp].lastSeenAt || "")) {
                    byFingerprint[fp].lastSeenAt = time
                    byFingerprint[fp].callId = callId(call)
                    byFingerprint[fp].status = call.status || ""
                    byFingerprint[fp].costMs = call.cost_ms !== undefined ? call.cost_ms : call.costMs
                }
            }
        }
        if (result.length === 0 && item) {
            result.push({
                fingerprint: fingerprint(item),
                callId: "",
                params: latestParams(item),
                paramsSummary: paramsSummary(item),
                firstSeenAt: item.first_seen_at || item.firstSeenAt || "",
                lastSeenAt: item.last_seen_at || item.lastSeenAt || "",
                seenCount: Math.max(1, sampleCount(item)),
                status: "",
                costMs: ""
            })
        }
        result.sort(function(a, b) { return String(b.lastSeenAt || "").localeCompare(String(a.lastSeenAt || "")) })
        for (var k = 0; k < result.length; k++) result[k].index = k + 1
        return result
    }

    function selectedSample() {
        var rows = sampleRows(selectedItem)
        if (rows.length === 0) return null
        return rows[Math.max(0, Math.min(selectedSampleIndex, rows.length - 1))]
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

    function overviewRows(item) {
        return [
            ["objectName", objectName(item)],
            ["cmdName", cmdName(item)],
            ["slotId", slotText(item)],
            ["serviceName", textOf(item ? (item.service_name || item.serviceName) : "")],
            ["sessionId", textOf(item ? (item.session_id || item.sessionId) : "")],
            ["调用次数", textOf(item ? (item.call_count || item.callCount || 0) : 0)],
            ["参数样本", textOf(sampleCount(item))],
            ["异常数", textOf(item ? (item.exception_count || item.exceptionCount || 0) : 0)],
            ["平均耗时", avgCostText(item) + " ms"],
            ["最大耗时", textOf(item ? (item.max_cost_ms || item.maxCostMs || 0) : 0) + " ms"],
            ["首次发现", shortTime(item ? (item.first_seen_at || item.firstSeenAt) : "")],
            ["最近调用", shortTime(item ? (item.last_seen_at || item.lastSeenAt) : "")]
        ]
    }

    function breakpointRows(item) {
        var rows = interfaceBreakpoints(item)
        return [
            ["断点数量", String(rows.length)],
            ["启用数量", String(enabledBreakpointCount(item))]
        ]
    }

    function uniqueRows(item) {
        return [
            ["唯一键", uniqueKey(item)],
            ["paramsFingerprint", fingerprint(item)]
        ]
    }

    component FilterCombo: ComboBox {
        id: combo
        implicitHeight: 36
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

    component RelatedCell: Text {
        property int cellWidth: 64
        Layout.preferredWidth: cellWidth
        Layout.minimumWidth: cellWidth
        color: page.appTheme.textNormal
        font.pixelSize: 12
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    component MetricCell: Rectangle {
        id: metric
        property string label: ""
        property string value: ""
        property string type: "neutral"

        Layout.preferredWidth: 102
        Layout.preferredHeight: 34
        radius: 4
        color: type === "success" ? page.appTheme.successSoft
              : type === "warning" ? page.appTheme.warningSoft
              : type === "danger" ? page.appTheme.dangerSoft
              : type === "primary" ? page.appTheme.primarySoft
              : page.appTheme.panelBg
        border.color: type === "success" ? page.appTheme.success
                    : type === "warning" ? page.appTheme.warning
                    : type === "danger" ? page.appTheme.danger
                    : type === "primary" ? page.appTheme.primary
                    : page.appTheme.border

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6
            Text {
                text: metric.label
                color: page.appTheme.textMuted
                font.pixelSize: 11
                Layout.preferredWidth: 30
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                text: metric.value
                color: metric.type === "success" ? page.appTheme.success
                      : metric.type === "warning" ? page.appTheme.warning
                      : metric.type === "danger" ? page.appTheme.danger
                      : metric.type === "primary" ? page.appTheme.primary
                      : page.appTheme.textStrong
                font.pixelSize: 12
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.minimumWidth: 700
            Layout.fillHeight: true
            color: appTheme.panelBg
            border.color: appTheme.border
            radius: 4

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 58
                    color: appTheme.panelBg
                    border.color: appTheme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 10
                        Text { text: "已发现接口"; color: appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        MbButton { appTheme: page.appTheme; text: "刷新"; iconText: "↻"; variant: "neutral"; Layout.preferredWidth: 92; Layout.preferredHeight: 38; onClicked: bridge.refreshAll() }
                        MbButton { appTheme: page.appTheme; text: "全部展开"; iconText: "⌄"; variant: "neutral"; Layout.preferredWidth: 106; Layout.preferredHeight: 38; onClicked: page.setAllExpanded(true) }
                        MbButton { appTheme: page.appTheme; text: "全部收起"; iconText: "⌃"; variant: "neutral"; Layout.preferredWidth: 106; Layout.preferredHeight: 38; onClicked: page.setAllExpanded(false) }
                        MbButton { appTheme: page.appTheme; text: page.onlyWithBreakpoints ? "显示全部" : "只看断点"; iconText: "◎"; variant: page.onlyWithBreakpoints ? "primary" : "neutral"; Layout.preferredWidth: 110; Layout.preferredHeight: 38; onClicked: page.onlyWithBreakpoints = !page.onlyWithBreakpoints }
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
                                        Layout.preferredHeight: 46
                                        color: page.isExpanded(modelData.objectName) ? page.appTheme.panelActive : page.appTheme.panelBgAlt
                                        border.color: page.appTheme.border
                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.leftMargin: 12
                                            anchors.rightMargin: 12
                                            spacing: 12
                                            Text { text: page.isExpanded(modelData.objectName) ? "▾" : "▸"; color: page.appTheme.primary; font.pixelSize: 16; font.weight: Font.DemiBold }
                                            Text { text: modelData.objectName; color: page.appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.preferredWidth: 96; elide: Text.ElideRight }
                                            MbTag { appTheme: page.appTheme; text: "接口 " + modelData.rows.length; type: "primary"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "调用 " + modelData.callCount; type: "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "样本 " + modelData.sampleCount; type: "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "异常 " + modelData.exceptionCount; type: modelData.exceptionCount > 0 ? "danger" : "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "启用断点 " + modelData.enabledBreakpointCount; type: modelData.enabledBreakpointCount > 0 ? "success" : "neutral"; Layout.preferredWidth: 112 }
                                            Item { Layout.fillWidth: true }
                                        }
                                        MouseArea { anchors.fill: parent; onClicked: page.setExpanded(modelData.objectName, !page.isExpanded(modelData.objectName)) }
                                    }

                                    ColumnLayout {
                                        visible: page.isExpanded(modelData.objectName)
                                        Layout.fillWidth: true
                                        Layout.margins: 12
                                        spacing: 8

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10
                                            MbTextField {
                                                appTheme: page.appTheme
                                                Layout.preferredWidth: 360
                                                Layout.preferredHeight: 36
                                                placeholderText: "搜索 " + modelData.objectName + " 内接口（命令 / 槽位 / 参数）"
                                                text: page.groupSearch(modelData.objectName)
                                                onTextChanged: page.groupSearches = page.setStoreValue(page.groupSearches, modelData.objectName, text)
                                            }
                                            Text { text: "排序"; color: page.appTheme.textMuted; font.pixelSize: 12 }
                                            FilterCombo {
                                                Layout.preferredWidth: 134
                                                model: ["最近调用", "调用次数", "平均耗时", "异常数量", "命令名称"]
                                                currentIndex: Math.max(0, model.indexOf(page.groupSort(modelData.objectName)))
                                                onActivated: page.groupSorts = page.setStoreValue(page.groupSorts, modelData.objectName, currentText)
                                            }
                                            Item { Layout.fillWidth: true }
                                        }

                                        Repeater {
                                            model: page.filteredRows(modelData)
                                            delegate: Rectangle {
                                                required property var modelData
                                                property string idValue: page.itemId(modelData)
                                                property int enabledBps: page.enabledBreakpointCount(modelData)
                                                Layout.fillWidth: true
                                                implicitHeight: 136
                                                radius: 4
                                                color: page.selectedInterfaceId === idValue ? page.appTheme.panelActive : page.appTheme.panelBgAlt
                                                border.color: page.selectedInterfaceId === idValue ? page.appTheme.primary : page.appTheme.border

                                                MouseArea { anchors.fill: parent; onClicked: page.selectedInterfaceId = idValue }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    spacing: 12

                                                    Rectangle { Layout.preferredWidth: 4; Layout.fillHeight: true; radius: 2; color: enabledBps > 0 ? page.appTheme.success : page.appTheme.primary }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        Layout.fillHeight: true
                                                        spacing: 6
                                                        Text { text: page.cmdName(modelData); color: page.appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        Text { text: page.objectName(modelData) + " / 槽位 " + page.slotText(modelData) + " / 命令接口"; color: page.appTheme.textNormal; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        Text { text: "参数摘要: " + page.paramsSummary(modelData); color: page.appTheme.textMuted; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        Text { text: "唯一键: " + page.uniqueKey(modelData); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        Text { text: "最近调用 " + page.shortTime(modelData.last_seen_at || modelData.lastSeenAt); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        Item { Layout.fillHeight: true }
                                                    }

                                                    GridLayout {
                                                        Layout.preferredWidth: 338
                                                        Layout.minimumWidth: 338
                                                        Layout.maximumWidth: 338
                                                        Layout.alignment: Qt.AlignVCenter
                                                        columns: 3
                                                        rowSpacing: 8
                                                        columnSpacing: 8
                                                        MetricCell { label: "断点"; value: enabledBps > 0 ? "已启用" : "未设"; type: enabledBps > 0 ? "success" : "neutral" }
                                                        MetricCell { label: "调用"; value: String(modelData.call_count || 0); type: "primary" }
                                                        MetricCell { label: "样本"; value: String(page.sampleCount(modelData)); type: page.sampleCount(modelData) > 1 ? "primary" : "neutral" }
                                                        MetricCell { label: "异常"; value: String(modelData.exception_count || 0); type: (modelData.exception_count || 0) > 0 ? "danger" : "neutral" }
                                                        MetricCell { label: "平均"; value: page.avgCostText(modelData) + "ms"; type: "neutral" }
                                                        MetricCell { label: "最近"; value: page.shortTime(modelData.last_seen_at || modelData.lastSeenAt).split(" ").pop(); type: "neutral" }
                                                    }

                                                    ColumnLayout {
                                                        Layout.preferredWidth: 128
                                                        Layout.minimumWidth: 128
                                                        Layout.maximumWidth: 128
                                                        Layout.alignment: Qt.AlignVCenter
                                                        spacing: 6
                                                        MbButton { appTheme: page.appTheme; text: "查看样本"; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 26; onClicked: { page.selectedInterfaceId = idValue; page.selectedSampleIndex = 0; page.detailTabIndex = 1 } }
                                                        MbButton { appTheme: page.appTheme; text: "相关调用"; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 26; onClicked: { page.selectedInterfaceId = idValue; page.detailTabIndex = 2 } }
                                                        MbButton { appTheme: page.appTheme; text: enabledBps > 0 ? "已启用断点" : "创建断点"; variant: enabledBps > 0 ? "success" : "primary"; enabled: enabledBps === 0; Layout.fillWidth: true; Layout.preferredHeight: 26; onClicked: bridge.createBreakpointFromInterface(idValue) }
                                                        MbButton { appTheme: page.appTheme; text: "复制请求"; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 26; onClicked: bridge.copyText(page.jsonText({objectName: page.objectName(modelData), cmdName: page.cmdName(modelData), slotId: page.slotText(modelData), params: page.latestParams(modelData)})) }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            visible: page.filteredRows(modelData).length === 0
                                            text: "当前分组无匹配结果"
                                            color: page.appTheme.textMuted
                                            font.pixelSize: 13
                                            Layout.leftMargin: 8
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
                                Text { text: "暂无已发现接口"; color: page.appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                Text { text: "开始调试后，Java 上报的接口会自动出现在这里。"; color: page.appTheme.textMuted; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 460
            Layout.minimumWidth: 440
            Layout.maximumWidth: 500
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
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "接口详情"; color: appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 0
                    TabButton { text: "概览"; selected: page.detailTabIndex === 0; Layout.preferredWidth: 78; onClicked: page.detailTabIndex = 0 }
                    TabButton { text: "样本"; selected: page.detailTabIndex === 1; Layout.preferredWidth: 82; onClicked: page.detailTabIndex = 1 }
                    TabButton { text: "相关调用"; selected: page.detailTabIndex === 2; Layout.preferredWidth: 96; onClicked: page.detailTabIndex = 2 }
                    TabButton { text: "原始 JSON"; selected: page.detailTabIndex === 3; Layout.fillWidth: true; onClicked: page.detailTabIndex = 3 }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: page.detailTabIndex

                    ScrollView {
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ColumnLayout {
                            x: 12
                            y: 12
                            width: Math.max(0, (parent ? parent.width : 430) - 24)
                            spacing: 10
                            MbDetailCard { appTheme: page.appTheme; title: "接口身份"; rows: page.overviewRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "断点信息"; rows: page.breakpointRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "唯一性"; rows: page.uniqueRows(page.selectedItem) }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 12
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            spacing: 8
                            Text {
                                text: "参数样本 " + page.sampleRows(page.selectedItem).length + " 个"
                                color: page.appTheme.textStrong
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            MbButton {
                                appTheme: page.appTheme
                                text: "从该样本创建断点"
                                variant: "primary"
                                Layout.preferredWidth: 150
                                Layout.preferredHeight: 34
                                enabled: page.selectedSample() !== null && page.selectedSample().callId !== ""
                                onClicked: bridge.createBreakpointFromCall(page.selectedSample().callId)
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10

                            ListView {
                                id: sampleList
                                Layout.preferredWidth: 150
                                Layout.fillHeight: true
                                clip: true
                                model: page.sampleRows(page.selectedItem)
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: sampleList.width
                                    height: 68
                                    radius: 4
                                    color: page.selectedSampleIndex === index ? page.appTheme.panelActive : page.appTheme.panelBgAlt
                                    border.color: page.selectedSampleIndex === index ? page.appTheme.primary : page.appTheme.border
                                    MouseArea { anchors.fill: parent; onClicked: page.selectedSampleIndex = index }
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 2
                                        Text { text: "样本 #" + modelData.index; color: page.appTheme.textStrong; font.pixelSize: 13; font.weight: Font.DemiBold; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Text { text: page.shortTime(modelData.lastSeenAt); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Text { text: "次数 " + modelData.seenCount + " / " + page.shortFingerprint(modelData.fingerprint); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                                    }
                                }
                            }

                            MbJsonViewer {
                                appTheme: page.appTheme
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: page.jsonText(page.selectedSample() ? page.selectedSample().params : {})
                            }
                        }
                    }

                    ScrollView {
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ColumnLayout {
                            x: 12
                            y: 12
                            width: Math.max(0, (parent ? parent.width : 430) - 24)
                            spacing: 6

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                color: page.appTheme.panelBgAlt
                                border.color: page.appTheme.border
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8
                                    RelatedCell { text: "#"; cellWidth: 42; color: page.appTheme.textStrong; font.weight: Font.DemiBold }
                                    RelatedCell { text: "状态"; cellWidth: 62; color: page.appTheme.textStrong; font.weight: Font.DemiBold }
                                    RelatedCell { text: "耗时"; cellWidth: 62; color: page.appTheme.textStrong; font.weight: Font.DemiBold }
                                    RelatedCell { text: "时间"; cellWidth: 142; color: page.appTheme.textStrong; font.weight: Font.DemiBold }
                                    RelatedCell { text: "断点"; cellWidth: 58; color: page.appTheme.textStrong; font.weight: Font.DemiBold }
                                }
                            }

                            Repeater {
                                model: page.relatedCalls(page.selectedItem).slice(0, 12)
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    radius: 4
                                    color: page.appTheme.panelBgAlt
                                    border.color: page.appTheme.borderSoft
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        spacing: 8
                                        RelatedCell { text: String(modelData.call_index || modelData.callIndex || "-"); cellWidth: 42; color: page.appTheme.textStrong }
                                        RelatedCell { text: page.statusText(modelData.status); cellWidth: 62; color: page.appTheme.textNormal }
                                        RelatedCell { text: page.textOf(modelData.cost_ms !== undefined ? modelData.cost_ms : modelData.costMs) + " ms"; cellWidth: 62 }
                                        RelatedCell { text: page.shortTime(modelData.created_at || modelData.createdAt); cellWidth: 142; color: page.appTheme.textMuted }
                                        RelatedCell { text: modelData.breakpoint_id || modelData.breakpointId ? "命中" : "未命中"; cellWidth: 58; color: modelData.breakpoint_id || modelData.breakpointId ? page.appTheme.warning : page.appTheme.textMuted }
                                    }
                                }
                            }
                            Text {
                                visible: page.relatedCalls(page.selectedItem).length === 0
                                text: "暂无相关调用"
                                color: page.appTheme.textMuted
                                font.pixelSize: 13
                                Layout.margins: 12
                            }
                        }
                    }

                    MbJsonViewer { appTheme: page.appTheme; text: page.jsonText(page.selectedItem || {}) }
                }
            }
        }
    }
}
