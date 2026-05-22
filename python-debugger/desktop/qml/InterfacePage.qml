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
    property bool onlyWithBreakpoints: false
    property var expandedGroups: ({})
    property var groupSearches: ({})
    property var groupSorts: ({})
    property var editingAliases: ({})
    property var aliasDrafts: ({})
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
    function itemId(item) { return item ? String(item.id || item.interface_id || item.interfaceId || "") : "" }
    function objectName(item) { return String(item ? (item.object_name || item.objectName || "未分类") : "未分类") }
    function cmdName(item) { return String(item ? (item.cmd_name || item.cmdName || item.method_name || item.methodName || "-") : "-") }
    function slotText(item) {
        var value = item ? (item.slot_id !== undefined ? item.slot_id : item.slotId) : undefined
        return value === undefined || value === null || value === "" ? "无槽位" : String(value)
    }
    function latestParams(item) {
        return safeObject(item ? (item.latest_params || item.latestParams || item.latest_params_json || item.sample_args || item.sample_args_json || {}) : {}, {})
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
    function aliasText(item) {
        var alias = item ? (item.interface_alias || item.interfaceAlias || "") : ""
        return alias ? alias : "未设置"
    }
    function fingerprint(item) {
        var fp = item ? (item.latest_params_fingerprint || item.params_fingerprint || item.paramsFingerprint || "") : ""
        if (fp) return String(fp)
        var text = jsonText(latestParams(item))
        var hash = 0
        for (var i = 0; i < text.length; i++) hash = ((hash << 5) - hash + text.charCodeAt(i)) | 0
        return Math.abs(hash).toString(16)
    }
    function uniqueKey(item) {
        return cmdName(item) + " / " + slotText(item) + " / " + fingerprint(item)
    }
    function textOf(value) {
        if (value === undefined || value === null || value === "") return "-"
        return String(value)
    }
    function interfaceBreakpoint(interfaceId) {
        for (var i = 0; i < breakpoints.length; i++) {
            if (String(breakpoints[i].source_interface_id || breakpoints[i].sourceInterfaceId || "") === String(interfaceId)) return breakpoints[i]
        }
        return null
    }
    function breakpointEnabled(interfaceId) {
        var bp = interfaceBreakpoint(interfaceId)
        return bp ? !!bp.enabled : false
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
            return
        }
        if (selectedInterfaceId && selectedItemForId(selectedInterfaceId) && itemId(selectedItemForId(selectedInterfaceId)) === selectedInterfaceId) return
        selectedInterfaceId = itemId(items[0])
    }
    onItemsChanged: Qt.callLater(ensureSelection)

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
            var id = itemId(items[i])
            if (onlyWithBreakpoints && !interfaceBreakpoint(id)) continue
            var name = objectName(items[i])
            if (!map[name]) map[name] = {objectName: name, rows: [], callCount: 0, sampleCount: 0, exceptionCount: 0, enabledBreakpointCount: 0}
            var group = map[name]
            group.rows.push(items[i])
            group.callCount += Number(items[i].call_count || items[i].callCount || 0)
            group.sampleCount += Number(items[i].params_sample_count || items[i].paramsSampleCount || 0)
            group.exceptionCount += Number(items[i].exception_count || items[i].exceptionCount || 0)
            if (breakpointEnabled(id)) group.enabledBreakpointCount++
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
            var haystack = (cmdName(row) + " " + slotText(row) + " " + paramsSummary(row) + " " + uniqueKey(row) + " " + aliasText(row)).toLowerCase()
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
        result.sort(function(a, b) { return Number(b.call_index || 0) - Number(a.call_index || 0) })
        return result.slice(0, 8)
    }

    function overviewRows(item) {
        var bp = item ? interfaceBreakpoint(itemId(item)) : null
        return [
            ["objectName", objectName(item)],
            ["cmdName", cmdName(item)],
            ["slotId", slotText(item)],
            ["serviceName", textOf(item ? (item.service_name || item.serviceName) : "")],
            ["sessionId", textOf(item ? (item.session_id || item.sessionId) : "")],
            ["调用次数", textOf(item ? (item.call_count || item.callCount || 0) : 0)],
            ["样本数", textOf(item ? (item.params_sample_count || item.paramsSampleCount || 0) : 0)],
            ["异常数", textOf(item ? (item.exception_count || item.exceptionCount || 0) : 0)],
            ["平均耗时", textOf(item ? (item.avg_cost_ms || item.avgCostMs || 0) : 0) + " ms"],
            ["最大耗时", textOf(item ? (item.max_cost_ms || item.maxCostMs || 0) : 0) + " ms"],
            ["首次发现", shortTime(item ? (item.first_seen_at || item.firstSeenAt) : "")],
            ["最近调用", shortTime(item ? (item.last_seen_at || item.lastSeenAt) : "")],
            ["断点状态", bp ? (bp.enabled ? "已启用断点" : "断点已禁用") : "未设置"],
            ["已启用断点数量", bp && bp.enabled ? "1" : "0"],
            ["唯一键", uniqueKey(item)],
            ["paramsFingerprint", fingerprint(item)]
        ]
    }

    function identityRows(item) {
        return [
            ["objectName", objectName(item)],
            ["cmdName", cmdName(item)],
            ["slotId", slotText(item)],
            ["serviceName", textOf(item ? (item.service_name || item.serviceName) : "")],
            ["sessionId", textOf(item ? (item.session_id || item.sessionId) : "")]
        ]
    }

    function callStatRows(item) {
        return [
            ["调用次数", textOf(item ? (item.call_count || item.callCount || 0) : 0)],
            ["样本数", textOf(item ? (item.params_sample_count || item.paramsSampleCount || 0) : 0)],
            ["异常数", textOf(item ? (item.exception_count || item.exceptionCount || 0) : 0)],
            ["平均耗时", textOf(item ? (item.avg_cost_ms || item.avgCostMs || 0) : 0) + " ms"],
            ["最大耗时", textOf(item ? (item.max_cost_ms || item.maxCostMs || 0) : 0) + " ms"],
            ["首次发现", shortTime(item ? (item.first_seen_at || item.firstSeenAt) : "")],
            ["最近调用", shortTime(item ? (item.last_seen_at || item.lastSeenAt) : "")]
        ]
    }

    function breakpointRows(item) {
        var bp = item ? interfaceBreakpoint(itemId(item)) : null
        return [
            ["断点状态", bp ? (bp.enabled ? "已启用断点" : "断点已禁用") : "未设置"],
            ["已启用断点数量", bp && bp.enabled ? "1" : "0"]
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
                    Layout.preferredHeight: 54
                    color: appTheme.panelBg
                    border.color: appTheme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 10
                        Text { text: "已发现接口"; color: appTheme.textStrong; font.pixelSize: 16; font.weight: Font.DemiBold; Layout.fillWidth: true }
                        MbButton { appTheme: page.appTheme; text: "刷新"; iconText: "↻"; variant: "neutral"; implicitWidth: 88; onClicked: bridge.refreshAll() }
                        MbButton { appTheme: page.appTheme; text: "全部展开"; iconText: "⌄"; variant: "neutral"; implicitWidth: 104; onClicked: page.setAllExpanded(true) }
                        MbButton { appTheme: page.appTheme; text: "全部收起"; iconText: "⌃"; variant: "neutral"; implicitWidth: 104; onClicked: page.setAllExpanded(false) }
                        MbButton { appTheme: page.appTheme; text: page.onlyWithBreakpoints ? "显示全部" : "只看断点"; iconText: "◎"; variant: page.onlyWithBreakpoints ? "primary" : "neutral"; implicitWidth: 112; onClicked: page.onlyWithBreakpoints = !page.onlyWithBreakpoints }
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
                                            MbTag { appTheme: page.appTheme; text: "接口 " + modelData.rows.length; type: "primary"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "调用 " + modelData.callCount; type: "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "样本 " + modelData.sampleCount; type: "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "异常 " + modelData.exceptionCount; type: modelData.exceptionCount > 0 ? "danger" : "neutral"; Layout.preferredWidth: 84 }
                                            MbTag { appTheme: page.appTheme; text: "已启用断点 " + modelData.enabledBreakpointCount; type: modelData.enabledBreakpointCount > 0 ? "success" : "neutral"; Layout.preferredWidth: 120 }
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
                                                Layout.preferredHeight: 34
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
                                                property var bp: page.interfaceBreakpoint(idValue)
                                                property bool editing: !!page.editingAliases[idValue]
                                                Layout.fillWidth: true
                                                implicitHeight: editing ? 190 : 176
                                                radius: 4
                                                color: page.selectedInterfaceId === idValue ? page.appTheme.panelActive : page.appTheme.panelBgAlt
                                                border.color: page.selectedInterfaceId === idValue ? page.appTheme.primary : page.appTheme.border

                                                MouseArea { anchors.fill: parent; onClicked: page.selectedInterfaceId = idValue }

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 12
                                                    spacing: 12

                                                    Rectangle { Layout.preferredWidth: 4; Layout.fillHeight: true; radius: 2; color: bp ? (bp.enabled ? page.appTheme.success : page.appTheme.warning) : page.appTheme.primary }

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        Layout.minimumWidth: 0
                                                        Layout.fillHeight: true
                                                        spacing: 6
                                                        Text { text: page.cmdName(modelData); color: page.appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        Text { text: page.objectName(modelData) + " / 槽位 " + page.slotText(modelData) + " / 命令"; color: page.appTheme.textNormal; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        Text { text: "参数摘要: " + page.paramsSummary(modelData); color: page.appTheme.textMuted; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                        Text { text: "唯一键: " + page.uniqueKey(modelData); color: page.appTheme.textMuted; font.pixelSize: 11; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                    }

                                                    ColumnLayout {
                                                        Layout.preferredWidth: 260
                                                        Layout.minimumWidth: 260
                                                        Layout.fillHeight: true
                                                        spacing: 7
                                                        MbTag { appTheme: page.appTheme; text: bp && bp.enabled ? "已启用断点" : "未设断点"; type: bp && bp.enabled ? "success" : "neutral"; Layout.preferredWidth: 112 }
                                                        GridLayout {
                                                            Layout.fillWidth: true
                                                            columns: 2
                                                            rowSpacing: 6
                                                            columnSpacing: 8
                                                            MbTag { appTheme: page.appTheme; text: "调用 " + (modelData.call_count || 0); type: "neutral"; Layout.preferredWidth: 112 }
                                                            MbTag { appTheme: page.appTheme; text: "样本 " + (modelData.params_sample_count || 0); type: "neutral"; Layout.preferredWidth: 112 }
                                                            MbTag { appTheme: page.appTheme; text: "异常 " + (modelData.exception_count || 0); type: (modelData.exception_count || 0) > 0 ? "danger" : "neutral"; Layout.preferredWidth: 112 }
                                                            MbTag { appTheme: page.appTheme; text: "平均 " + (modelData.avg_cost_ms || 0) + "ms"; type: "neutral"; Layout.preferredWidth: 112 }
                                                        }
                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            visible: !editing
                                                            Text { text: "别名: " + page.aliasText(modelData); color: page.appTheme.textNormal; font.pixelSize: 12; Layout.fillWidth: true; Layout.minimumWidth: 0; elide: Text.ElideRight }
                                                            MbButton { appTheme: page.appTheme; text: "编辑"; variant: "ghost"; implicitWidth: 54; onClicked: {
                                                                page.editingAliases = page.setStoreValue(page.editingAliases, idValue, true)
                                                                page.aliasDrafts = page.setStoreValue(page.aliasDrafts, idValue, modelData.interface_alias || "")
                                                            } }
                                                        }
                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            visible: editing
                                                            MbTextField { id: aliasInput; appTheme: page.appTheme; Layout.fillWidth: true; Layout.preferredHeight: 32; text: page.aliasDrafts[idValue] || ""; onTextChanged: page.aliasDrafts = page.setStoreValue(page.aliasDrafts, idValue, text) }
                                                            MbButton { appTheme: page.appTheme; text: "保存"; variant: "primary"; implicitWidth: 58; onClicked: {
                                                                bridge.setInterfaceAlias(idValue, page.aliasDrafts[idValue] || "")
                                                                page.editingAliases = page.setStoreValue(page.editingAliases, idValue, false)
                                                            } }
                                                            MbButton { appTheme: page.appTheme; text: "取消"; variant: "neutral"; implicitWidth: 58; onClicked: page.editingAliases = page.setStoreValue(page.editingAliases, idValue, false) }
                                                        }
                                                    }

                                                    ColumnLayout {
                                                        Layout.preferredWidth: 150
                                                        Layout.minimumWidth: 150
                                                        Layout.fillHeight: true
                                                        spacing: 8
                                                        MbButton { appTheme: page.appTheme; text: "查看调用"; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 34; onClicked: { page.selectedInterfaceId = idValue; page.detailTabIndex = 3 } }
                                                        MbButton { appTheme: page.appTheme; text: bp && bp.enabled ? "已启用断点" : "创建断点"; variant: bp && bp.enabled ? "success" : "primary"; enabled: !(bp && bp.enabled); Layout.fillWidth: true; Layout.preferredHeight: 34; onClicked: bridge.createBreakpointFromInterface(idValue) }
                                                        MbButton { appTheme: page.appTheme; text: "复制请求"; variant: "neutral"; Layout.fillWidth: true; Layout.preferredHeight: 34; onClicked: bridge.copyText(page.jsonText({objectName: page.objectName(modelData), cmdName: page.cmdName(modelData), slotId: page.slotText(modelData), params: page.latestParams(modelData)})) }
                                                        Item { Layout.fillHeight: true }
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
                    Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; text: "接口详情"; color: appTheme.textStrong; font.pixelSize: 15; font.weight: Font.DemiBold }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    spacing: 0
                    TabButton { text: "概览"; selected: page.detailTabIndex === 0; Layout.preferredWidth: 70; onClicked: page.detailTabIndex = 0 }
                    TabButton { text: "参数结构"; selected: page.detailTabIndex === 1; Layout.preferredWidth: 78; onClicked: page.detailTabIndex = 1 }
                    TabButton { text: "样本参数"; selected: page.detailTabIndex === 2; Layout.preferredWidth: 78; onClicked: page.detailTabIndex = 2 }
                    TabButton { text: "相关调用"; selected: page.detailTabIndex === 3; Layout.preferredWidth: 78; onClicked: page.detailTabIndex = 3 }
                    TabButton { text: "原始 JSON"; selected: page.detailTabIndex === 4; Layout.fillWidth: true; onClicked: page.detailTabIndex = 4 }
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
                            width: Math.max(0, (parent ? parent.width : 400) - 24)
                            spacing: 10
                            MbDetailCard { appTheme: page.appTheme; title: "接口身份"; rows: page.identityRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "调用统计"; rows: page.callStatRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "断点信息"; rows: page.breakpointRows(page.selectedItem) }
                            MbDetailCard { appTheme: page.appTheme; title: "唯一性"; rows: page.uniqueRows(page.selectedItem) }
                        }
                    }
                    MbJsonViewer { appTheme: page.appTheme; text: page.jsonText(page.selectedItem ? (page.selectedItem.parameter_schema || page.selectedItem.parameter_schema_json || page.selectedItem.params_schema || {}) : {}) }
                    MbJsonViewer { appTheme: page.appTheme; text: page.jsonText({
                        sampleArgs: page.selectedItem ? (page.selectedItem.sample_args || page.selectedItem.sample_args_json || {}) : {},
                        latestParams: page.latestParams(page.selectedItem)
                    }) }
                    ScrollView {
                        clip: true
                        ColumnLayout {
                            x: 10
                            y: 10
                            width: Math.max(0, (parent ? parent.width : 400) - 20)
                            spacing: 4
                            Repeater {
                                model: page.relatedCalls(page.selectedItem)
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 34
                                    color: page.appTheme.panelBgAlt
                                    border.color: page.appTheme.borderSoft
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        anchors.rightMargin: 8
                                        Text { text: String(modelData.call_index || "-"); color: page.appTheme.textStrong; Layout.preferredWidth: 48 }
                                        Text { text: page.textOf(modelData.status); color: page.appTheme.textNormal; Layout.preferredWidth: 72; elide: Text.ElideRight }
                                        Text { text: page.textOf(modelData.cost_ms) + " ms"; color: page.appTheme.textNormal; Layout.preferredWidth: 82; elide: Text.ElideRight }
                                        Text { text: page.shortTime(modelData.created_at); color: page.appTheme.textMuted; Layout.fillWidth: true; elide: Text.ElideRight }
                                        Text { text: modelData.breakpoint_id ? "命中" : "未命中"; color: modelData.breakpoint_id ? page.appTheme.warning : page.appTheme.textMuted; Layout.preferredWidth: 56 }
                                    }
                                }
                            }
                            Text { visible: page.relatedCalls(page.selectedItem).length === 0; text: "暂无相关调用"; color: page.appTheme.textMuted; font.pixelSize: 13; Layout.margins: 12 }
                        }
                    }
                    MbJsonViewer { appTheme: page.appTheme; text: page.jsonText(page.selectedItem || {}) }
                }
            }
        }
    }
}
