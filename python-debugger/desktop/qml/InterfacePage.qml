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
    property var selectedDetail: selectedItem
    property int sampleLimit: 10

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
    function paramsSummary(item) {
        var summary = item ? (item.params_summary || item.paramsSummary) : ""
        if (summary) return String(summary)
        return "-"
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
        return ""
    }
    function shortFingerprint(value) {
        var text = String(value || "")
        return text.length > 12 ? text.slice(0, 12) : text
    }
    function uniqueKey(item) {
        return objectName(item) + " / " + cmdName(item)
    }
    function interfaceBreakpoints(item) {
        var result = []
        if (!item) return result
        for (var i = 0; i < breakpoints.length; i++) {
            var bp = breakpoints[i]
            var bpSession = String(bp.session_id || bp.sessionId || "")
            var itemSession = String(item.session_id || item.sessionId || "")
            var sameSession = !bpSession || !itemSession || bpSession === itemSession
            var sameMatch = sameSession && objectName(bp) === objectName(item) && cmdName(bp) === cmdName(item)
            if (sameMatch) result.push(bp)
        }
        result.sort(function(a, b) { return String(b.created_at || b.createdAt || "").localeCompare(String(a.created_at || a.createdAt || "")) })
        return result
    }
    function breakpointTypeLabel(item) {
        var label = item ? (item.breakpointTypeLabel || item.breakpoint_type_label) : ""
        if (label) return String(label)
        var mode = item ? (item.match_mode || item.matchMode || "command_only") : "command_only"
        return mode === "command_only" ? "命令断点" : "条件断点"
    }
    function conditionSummary(item) {
        if (!item) return "-"
        var mode = item.match_mode || item.matchMode || "command_only"
        if (mode === "command_only") return "命中该命令即暂停"
        var conditions = safeObject(item.conditions || item.conditions_json || [], [])
        if (conditions.length > 0) return jsonText(conditions).replace(/\s+/g, " ")
        var summary = item.params_summary || item.paramsSummary || item.params_hash || item.paramsHash || ""
        return summary ? String(summary) : "按参数指纹匹配"
    }
    function confirmDeleteBreakpoint(breakpointId, breakpointName) {
        confirmDialog.ask("删除断点", "将删除断点 " + breakpointName + "。此操作不可撤销。", "删除", function() {
            bridge.deleteBreakpoint(breakpointId)
        })
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
    onItemsChanged: Qt.callLater(function() {
        ensureSelection()
        selectedDetail = selectedInterfaceId ? JSON.parse(bridge.interfaceDetail(selectedInterfaceId)) : selectedItem
    })
    onSelectedInterfaceIdChanged: {
        selectedSampleIndex = 0
        sampleLimit = 10
        selectedDetail = selectedInterfaceId ? JSON.parse(bridge.interfaceDetail(selectedInterfaceId)) : selectedItem
    }

    ConfirmDialog {
        id: confirmDialog
        appTheme: page.appTheme
    }

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
            var haystack = (cmdName(row) + " " + paramsSummary(row) + " " + uniqueKey(row)).toLowerCase()
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
            if (objectName(calls[i]) === objectName(item) && cmdName(calls[i]) === cmdName(item)) result.push(calls[i])
        }
        result.sort(function(a, b) { return Number(b.call_index || b.callIndex || 0) - Number(a.call_index || a.callIndex || 0) })
        return result
    }

    function sampleRows(item) {
        var detailSamples = selectedDetail ? (selectedDetail.samples || []) : []
        if (detailSamples.length > 0) {
            var mapped = []
            for (var ds = 0; ds < detailSamples.length; ds++) {
                var sample = detailSamples[ds]
                mapped.push({
                    index: ds + 1,
                    fingerprint: sample.params_hash || sample.paramsHash || sample.params_fingerprint || sample.paramsFingerprint || "",
                    sampleId: sample.id || sample.sampleId || "",
                    callId: callId(sample),
                    paramsPayloadId: sample.params_payload_id || sample.paramsPayloadId || "",
                    objectName: objectName(sample),
                    cmdName: cmdName(sample),
                    slotId: slotText(sample),
                    paramsSummary: sample.params_summary || sample.paramsSummary || "-",
                    paramsPreview: sample.params_preview || sample.paramsPreview || "",
                    paramsSize: Number(sample.params_size || sample.paramsSize || 0),
                    paramsHash: sample.params_hash || sample.paramsHash || sample.params_fingerprint || sample.paramsFingerprint || "",
                    paramsTruncated: !!(sample.params_truncated || sample.paramsTruncated),
                    firstSeenAt: sample.first_seen_at || sample.firstSeenAt || "",
                    lastSeenAt: sample.last_seen_at || sample.lastSeenAt || "",
                    seenCount: sample.seen_count || sample.sampleCount || 1,
                    status: "",
                    costMs: sample.cost_ms || sample.costMs || ""
                })
            }
            return mapped
        }
        var rows = relatedCalls(item)
        var byFingerprint = {}
        var result = []
        for (var i = 0; i < rows.length; i++) {
            var call = rows[i]
            var fp = String(call.params_fingerprint || call.paramsFingerprint || "")
            if (!fp) {
                fp = ""
            }
            var sampleKey = slotText(call) + "|" + fp
            if (!byFingerprint[sampleKey]) {
                byFingerprint[sampleKey] = {
                    fingerprint: fp,
                    sampleId: "",
                    callId: callId(call),
                    paramsPayloadId: call.params_payload_id || call.paramsPayloadId || "",
                    objectName: objectName(call),
                    cmdName: cmdName(call),
                    slotId: slotText(call),
                    paramsSummary: call.params_summary || call.paramsSummary || paramsSummary(call),
                    paramsPreview: call.params_preview || call.paramsPreview || "",
                    paramsSize: Number(call.params_size || call.paramsSize || 0),
                    paramsHash: call.params_hash || call.paramsHash || fp,
                    paramsTruncated: !!(call.params_truncated || call.paramsTruncated),
                    firstSeenAt: call.created_at || call.createdAt || "",
                    lastSeenAt: call.created_at || call.createdAt || "",
                    seenCount: 1,
                    status: call.status || "",
                    costMs: call.cost_ms !== undefined ? call.cost_ms : call.costMs
                }
                result.push(byFingerprint[sampleKey])
            } else {
                byFingerprint[sampleKey].seenCount += 1
                var time = call.created_at || call.createdAt || ""
                if (String(time) > String(byFingerprint[sampleKey].lastSeenAt || "")) {
                    byFingerprint[sampleKey].lastSeenAt = time
                    byFingerprint[sampleKey].callId = callId(call)
                    byFingerprint[sampleKey].status = call.status || ""
                    byFingerprint[sampleKey].costMs = call.cost_ms !== undefined ? call.cost_ms : call.costMs
                }
            }
        }
        if (result.length === 0 && item) {
            result.push({
                fingerprint: fingerprint(item),
                sampleId: "",
                callId: "",
                paramsPayloadId: item.params_payload_id || item.paramsPayloadId || "",
                objectName: objectName(item),
                cmdName: cmdName(item),
                slotId: slotText(item),
                paramsSummary: paramsSummary(item),
                paramsPreview: "",
                paramsSize: 0,
                paramsHash: fingerprint(item),
                paramsTruncated: false,
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
        var rows = sampleRows(selectedDetail || selectedItem)
        if (rows.length === 0) return null
        return rows[Math.max(0, Math.min(selectedSampleIndex, rows.length - 1))]
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

    function overviewRows(item) {
        return [
            ["对象", objectName(item)],
            ["命令", cmdName(item)],
            ["服务", textOf(item ? (item.service_name || item.serviceName) : "")],
            ["会话", textOf(item ? (item.session_id || item.sessionId) : "")],
            ["调用/样本", textOf(item ? (item.call_count || item.callCount || 0) : 0) + " / " + textOf(sampleCount(item))],
            ["异常/平均", textOf(item ? (item.exception_count || item.exceptionCount || 0) : 0) + " / " + avgCostText(item) + " ms"],
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
            ["规则", "sessionId + objectName + cmdName"],
            ["唯一键", uniqueKey(item)],
            ["参数指纹", fingerprint(item)]
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
                        Text { text: "接口列表"; color: appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
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
                                                placeholderText: "搜索 " + modelData.objectName + " 内接口（命令 / 参数）"
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
                                                        Text { text: page.objectName(modelData) + " / 命令接口"; color: page.appTheme.textNormal; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
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
                                                        MbButton { appTheme: page.appTheme; text: "复制摘要"; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 26; onClicked: bridge.copyText(page.paramsSummary(modelData)) }
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
                                Text { text: "暂无接口"; color: page.appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter }
                                Text { text: "开始调试后，Java 上报的接口会自动出现在这里。"; color: page.appTheme.textMuted; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 520
            Layout.minimumWidth: 500
            Layout.maximumWidth: 560
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
                    TabButton { text: "概览"; selected: page.detailTabIndex === 0; Layout.fillWidth: true; Layout.preferredWidth: 1; onClicked: page.detailTabIndex = 0 }
                    TabButton { text: "样本"; selected: page.detailTabIndex === 1; Layout.fillWidth: true; Layout.preferredWidth: 1; onClicked: page.detailTabIndex = 1 }
                    TabButton { text: "相关调用"; selected: page.detailTabIndex === 2; Layout.fillWidth: true; Layout.preferredWidth: 1; onClicked: page.detailTabIndex = 2 }
                    TabButton { text: "原始 JSON"; selected: page.detailTabIndex === 3; Layout.fillWidth: true; Layout.preferredWidth: 1; onClicked: page.detailTabIndex = 3 }
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
                            width: Math.max(0, (parent ? parent.width : 430) - 24)
                            spacing: 10
                            MbDetailCard { appTheme: page.appTheme; title: "接口身份"; labelWidth: 72; rows: page.overviewRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "断点信息"; labelWidth: 72; rows: page.breakpointRows(page.selectedItem) }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: breakpointInfoColumn.implicitHeight + 24
                                radius: 5
                                color: page.appTheme.panelBgAlt
                                border.color: page.appTheme.borderSoft

                                ColumnLayout {
                                    id: breakpointInfoColumn
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 8

                                    Repeater {
                                        model: page.interfaceBreakpoints(page.selectedItem)
                                        delegate: Rectangle {
                                            required property var modelData
                                            property string bpId: String(modelData.id || modelData.breakpointId || "")
                                            Layout.fillWidth: true
                                            implicitHeight: bpLayout.implicitHeight + 14
                                            radius: 4
                                            color: page.appTheme.panelBg
                                            border.color: page.appTheme.border

                                            ColumnLayout {
                                                id: bpLayout
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.margins: 7
                                                spacing: 5

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 8
                                                    Rectangle { Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4; color: modelData.enabled ? page.appTheme.success : page.appTheme.textDisabled }
                                                    MbTag { appTheme: page.appTheme; text: modelData.enabled ? "已启用" : "已禁用"; type: modelData.enabled ? "success" : "neutral"; Layout.preferredWidth: 68 }
                                                    MbTag { appTheme: page.appTheme; text: page.breakpointTypeLabel(modelData); type: (modelData.match_mode || modelData.matchMode) === "command_only" ? "neutral" : "primary"; Layout.preferredWidth: 78 }
                                                    Text { text: page.objectName(modelData) + " / " + page.cmdName(modelData); color: page.appTheme.textStrong; font.pixelSize: 12; font.weight: Font.DemiBold; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                }

                                                Text { text: page.conditionSummary(modelData); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }

                                                RowLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 6
                                                    Text { text: "命中 " + page.textOf(modelData.hit_count || modelData.hitCount || 0) + " / " + page.shortTime(modelData.created_at || modelData.createdAt); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                    MbButton { appTheme: page.appTheme; text: modelData.enabled ? "禁用" : "启用"; variant: modelData.enabled ? "neutral" : "success"; Layout.preferredWidth: 64; Layout.preferredHeight: 28; onClicked: bridge.setBreakpointEnabled(bpId, !modelData.enabled) }
                                                    MbButton { appTheme: page.appTheme; text: "删除"; variant: "danger"; Layout.preferredWidth: 64; Layout.preferredHeight: 28; onClicked: page.confirmDeleteBreakpoint(bpId, page.objectName(modelData) + " " + page.cmdName(modelData)) }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        visible: page.interfaceBreakpoints(page.selectedItem).length === 0
                                        text: "当前接口暂无断点"
                                        color: page.appTheme.textMuted
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                            MbDetailCard { appTheme: page.appTheme; title: "唯一性"; labelWidth: 72; rows: page.uniqueRows(page.selectedItem) }
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
                                text: "参数样本 " + page.sampleRows(page.selectedDetail || page.selectedItem).length + " 个"
                                color: page.appTheme.textStrong
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10

                            ListView {
                                id: sampleList
                                Layout.fillWidth: true
                                Layout.preferredHeight: 86
                                clip: true
                                orientation: ListView.Horizontal
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.HorizontalFlick
                                interactive: contentWidth > width
                                spacing: 8
                                model: page.sampleRows(page.selectedDetail || page.selectedItem)
                                ScrollBar.horizontal: ScrollBar {
                                    policy: sampleList.contentWidth > sampleList.width ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                                    contentItem: Rectangle { implicitHeight: 8; radius: 4; color: parent.pressed ? page.appTheme.primary : page.appTheme.textDisabled }
                                    background: Rectangle { color: page.appTheme.panelBgAlt; radius: 4 }
                                }
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: 160
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
                                        Text { text: "slotId " + modelData.slotId + " / " + page.shortTime(modelData.lastSeenAt); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Text { text: "次数 " + modelData.seenCount + " / " + page.shortFingerprint(modelData.fingerprint); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                                    }
                                }
                            }

                            LargePayloadViewer {
                                appTheme: page.appTheme
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                payloadId: page.selectedSample() ? page.selectedSample().paramsPayloadId : ""
                                callId: page.selectedSample() ? page.selectedSample().callId : ""
                                payloadType: "params"
                                title: "参数样本"
                                preview: page.selectedSample() ? page.selectedSample().paramsPreview : ""
                                payloadSize: page.selectedSample() ? page.selectedSample().paramsSize : 0
                                payloadHash: page.selectedSample() ? page.selectedSample().paramsHash : ""
                                truncated: page.selectedSample() ? page.selectedSample().paramsTruncated : false
                                extraActionText: "条件断点"
                                extraActionEnabled: page.selectedSample() !== null && page.selectedSample().callId !== ""
                                onExtraActionRequested: bridge.createBreakpointFromCall(page.selectedSample().callId)
                            }
                        }
                    }

                    ScrollView {
                        id: relatedCallScroll
                        clip: true
                        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                        contentWidth: availableWidth
                        contentHeight: relatedCallColumn.implicitHeight + 24
                        Column {
                            id: relatedCallColumn
                            x: 12
                            y: 12
                            width: Math.max(0, relatedCallScroll.availableWidth - 24)
                            spacing: 8

                            Repeater {
                                model: page.relatedCalls(page.selectedItem).slice(0, 12)
                                delegate: Rectangle {
                                    required property var modelData
                                    width: relatedCallColumn.width
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
                                                text: "调用 #" + String(modelData.call_index || modelData.callIndex || "-")
                                                color: page.appTheme.textStrong
                                                font.pixelSize: 13
                                                font.weight: Font.DemiBold
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            MbTag { appTheme: page.appTheme; text: page.statusText(modelData.status); type: page.statusType(modelData.status); Layout.preferredWidth: 64 }
                                            MbTag { appTheme: page.appTheme; text: modelData.breakpoint_id || modelData.breakpointId ? "命中" : "未命中"; type: modelData.breakpoint_id || modelData.breakpointId ? "warning" : "neutral"; Layout.preferredWidth: 72 }
                                        }
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 8
                                            Text {
                                                text: page.objectName(modelData) + " / " + page.cmdName(modelData) + " / 槽位 " + page.slotText(modelData)
                                                color: page.appTheme.textNormal
                                                font.pixelSize: 12
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }
                                            Text {
                                                text: page.textOf(modelData.cost_ms !== undefined ? modelData.cost_ms : modelData.costMs) + " ms"
                                                color: page.appTheme.textStrong
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                            }
                                        }
                                        Text {
                                            text: page.shortTime(modelData.created_at || modelData.createdAt)
                                            color: page.appTheme.textMuted
                                            font.pixelSize: 11
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }
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

                    MbJsonViewer { appTheme: page.appTheme; text: page.jsonText(page.selectedItem ? {
                        objectName: page.objectName(page.selectedItem),
                        cmdName: page.cmdName(page.selectedItem),
                        paramsSummary: page.paramsSummary(page.selectedItem),
                        sampleCount: page.sampleCount(page.selectedItem)
                    } : {}) }
                }
            }
        }
    }
}
