from pathlib import Path

from desktop.bridge import Bridge


QML_ROOT = Path(__file__).resolve().parents[1] / "desktop" / "qml"


def test_theme_mode_persists_between_bridge_instances():
    bridge = Bridge()
    original = bridge.getThemeMode()
    try:
        bridge.setThemeMode("light")
        assert Bridge().getThemeMode() == "light"

        bridge.setThemeMode("dark")
        assert Bridge().getThemeMode() == "dark"

        bridge.setThemeMode("unexpected")
        assert Bridge().getThemeMode() == "dark"
    finally:
        bridge.setThemeMode(original)


def test_call_record_filter_includes_interface_alias():
    qml = (QML_ROOT / "CallRecordPage.qml").read_text(encoding="utf-8")

    assert "item.interface_alias || item.interfaceAlias" in qml


def test_call_record_uses_business_debug_fields():
    qml = (QML_ROOT / "CallRecordPage.qml").read_text(encoding="utf-8")

    assert "object_name" in qml
    assert "cmd_name" in qml
    assert "params_summary" in qml
    assert "objectName(item)" in qml
    assert "cmdName(item)" in qml
    assert "interfaceRegistered(item)" in qml
    assert "args.instType" not in qml
    assert "加入接口列表" in qml
    assert "bridge.addInterfaceFromCall" in qml
    assert "imported_paused" in qml
    assert "历史暂停" in qml
    assert 'page.statusValue(page.selectedItem) === "paused"' in qml
    assert 'label: "断点"' in qml
    assert 'label: "接口"' in qml
    assert 'label: "标记"' not in qml
    assert 'label: "接口状态"' not in qml
    assert 'label: "线程名"' not in qml
    assert 'label: "调用时间"' not in qml


def test_qml_does_not_render_full_payloads_in_lists_or_logs():
    qml_text = "\n".join(
        (QML_ROOT / name).read_text(encoding="utf-8")
        for name in ("CallRecordPage.qml", "InterfacePage.qml", "BreakpointPage.qml", "InterfaceTab.qml", "BreakpointTab.qml")
    )
    bridge = (QML_ROOT.parent / "bridge.py").read_text(encoding="utf-8")

    forbidden = [
        "model.params",
        "model.result",
        "modelData.params ||",
        "modelData.params_json",
        "selectedItem.result",
        "params_json",
        "result_json",
        "latest_params ||",
        "latest_params_json",
        "sample_args ||",
        "sample_args_json",
        "JSON.stringify(item.latest_params",
        "JSON.stringify(modelData.params",
        "JSON.stringify(modelData.result",
    ]
    for pattern in forbidden:
        assert pattern not in qml_text
    assert "LargePayloadViewer" in qml_text
    assert "_log_safe_value" in bridge
    assert "loadPayloadChunk" in bridge
    assert "loadPayloadChunkById" in bridge
    assert "exportPayload" in bridge
    assert "exportPayloadById" in bridge


def test_large_payload_viewer_formats_json_and_shows_line_numbers():
    viewer = (QML_ROOT / "components" / "LargePayloadViewer.qml").read_text(encoding="utf-8")

    assert "function formatJsonPreview" in viewer
    assert "JSON.stringify(JSON.parse(trimmed), null, 2)" in viewer
    assert "function lineNumbers" in viewer
    assert "text: viewer.lineNumbers(viewer.displayText)" in viewer
    assert "acceptedButtons: Qt.AllButtons" in viewer
    assert "onPressed: function(mouse) { mouse.accepted = true }" in viewer
    assert "wrapMode: TextEdit.NoWrap" in viewer
    assert "selectByMouse: true" in viewer
    assert "flickableDirection: Flickable.HorizontalAndVerticalFlick" in viewer
    assert "verticalAlignment: TextInput.AlignVCenter" in viewer
    assert "property string payloadId" in viewer
    assert "property bool loadedFromChunks" in viewer
    assert "property bool loadingAll" in viewer
    assert "property bool loadedAll" in viewer
    assert "onTruncatedChanged: resetContent()" in viewer
    assert "function previewIsComplete()" in viewer
    assert "loadedAll = previewIsComplete()" in viewer
    assert "function loadAll()" in viewer
    assert "var offset = 0" in viewer
    assert "chunks.join(\"\")" in viewer
    assert "function loadMore" not in viewer
    assert "加载全部" in viewer
    assert "Popup {" in viewer
    assert "component SearchField" in viewer
    assert "搜索完整 payload" in viewer
    assert "function searchSummary" in viewer
    assert "searchResultPopup.open()" in viewer
    assert "viewer.selectedSearchIndex === index" in viewer


def test_interface_samples_use_payload_id_viewer():
    qml = (QML_ROOT / "InterfacePage.qml").read_text(encoding="utf-8")

    assert "paramsPayloadId: sample.params_payload_id || sample.paramsPayloadId || \"\"" in qml
    assert "payloadId: page.selectedSample() ? page.selectedSample().paramsPayloadId : \"\"" in qml


def test_call_record_page_keeps_filters_inside_groups():
    qml = (QML_ROOT / "CallRecordPage.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "CallRecordPage" in main
    assert not (QML_ROOT / "CallRecordTab.qml").exists()
    assert "搜索 \" + modelData.objectName + \" 内调用" in qml
    assert "HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName" in qml
    assert "property var columnWidths: [64, 170, 64, 240, 82, 76, 96, 96]" in qml
    assert "function setColumnWidth" in qml
    assert "function isResizableColumn" in qml
    assert "index === 1 || index === 3" in qml
    assert "function tableContentWidth" in qml
    assert "columnsWereResized && total > available ? total : available" in qml
    assert "component TagCell" in qml
    assert "已命中" in qml
    assert "已登记" in qml
    assert 'label: "对象"' not in qml
    assert "function setSort" in qml
    assert "function pagedRows" not in qml
    assert "Flickable {" in qml
    assert "flickableDirection: Flickable.HorizontalFlick" in qml
    assert "interactive: false" in qml
    assert "function pagedRows" not in qml
    assert "onSelectedCallIdChanged" in qml
    assert "detailTabIndex = 0" in qml
    assert "selectedCallChanged" in qml
    assert "当前分组显示" in qml


def test_interface_page_uses_grouped_cards_and_detail_tabs():
    qml = (QML_ROOT / "InterfacePage.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "InterfacePage" in main
    assert "搜索 \" + modelData.objectName + \" 内接口" in qml
    assert "全部展开" in qml
    assert "只看断点" in qml
    assert "查看样本" in qml
    assert "创建条件断点" in qml
    assert "别名" not in qml
    assert "component MetricCell" in qml
    assert "Layout.preferredWidth: 338" in qml
    assert "columns: 3" in qml
    assert "Layout.preferredWidth: 128" in qml
    assert qml.count('Layout.preferredHeight: 26') >= 4
    assert "MbDetailCard" in qml
    assert "接口身份" in qml
    assert "sessionId + objectName + cmdName" in qml
    assert "LargePayloadViewer" in qml
    assert "page.selectedSample().paramsPreview" in qml
    assert "loadMoreSamples" not in qml
    assert 'TabButton { text: "概览"; selected: page.detailTabIndex === 0; Layout.fillWidth: true' in qml
    assert 'TabButton { text: "样本"; selected: page.detailTabIndex === 1; Layout.fillWidth: true' in qml
    assert 'TabButton { text: "相关调用"; selected: page.detailTabIndex === 2; Layout.fillWidth: true' in qml
    assert 'TabButton { text: "原始 JSON"; selected: page.detailTabIndex === 3; Layout.fillWidth: true' in qml
    assert "参数样本" in qml
    assert "相关调用" in qml
    assert '"调用 #"' in qml
    assert "id: relatedCallScroll" in qml
    assert "contentHeight: relatedCallColumn.implicitHeight + 24" in qml
    assert "width: relatedCallColumn.width" in qml
    assert "RelatedCell" not in qml
    assert "原始 JSON" in qml


def test_interface_page_shows_related_breakpoints_by_business_fields():
    qml = (QML_ROOT / "InterfacePage.qml").read_text(encoding="utf-8")

    assert "function interfaceBreakpoints" in qml
    assert "objectName(bp) === objectName(item) && cmdName(bp) === cmdName(item)" in qml
    assert "当前接口暂无断点" in qml
    assert "page.breakpointTypeLabel(modelData)" in qml
    assert "bridge.setBreakpointEnabled(bpId, !modelData.enabled)" in qml
    assert "page.confirmDeleteBreakpoint(bpId" in qml


def test_call_record_page_shows_breakpoint_list_in_detail_panel():
    qml = (QML_ROOT / "CallRecordPage.qml").read_text(encoding="utf-8")

    assert "id: breakpointList" in qml
    assert "id: breakpointTabList" not in qml
    assert "TabButton { text: \"断点\"" not in qml
    assert "断点列表 (" in qml
    assert "当前 Session" in qml
    assert "page.breakpointTitle(modelData)" in qml
    assert "endsWith(\" breakpoint\")" in qml
    assert "if (mode !== \"command_only\") text += \" / 槽位 \"" in qml
    assert "bridge.setBreakpointEnabled(modelData.id, value)" in qml
    assert "signal selectedCallChanged" in qml
    assert "notifySelectedCallChanged()" in qml


def test_breakpoint_page_uses_grouped_cards_filters_and_hit_jump():
    qml = (QML_ROOT / "BreakpointPage.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "BreakpointPage" in main
    assert "objectOptions" in qml
    assert "搜索断点 / 命令 / 槽位" in qml
    assert "function groups" in qml
    assert "命中范围" in qml
    assert "function breakpointName" in qml
    assert "endsWith(\" breakpoint\")" in qml
    assert "page.breakpointName(modelData)" in qml
    assert "Text { text: page.shortTime(modelData.created_at || modelData.createdAt)" in qml
    assert "page.objectName(modelData) + \" / \" + page.cmdName(modelData) + \" / 槽位 \" + page.slotText(modelData) + \" / Session \"" not in qml
    assert "无附加参数条件，命中该命令即暂停。" in qml
    assert "requestCallFilter" in qml
    assert "root.callBreakpointFilter = breakpointId" in main
    assert "MbDetailCard" in qml
    assert "断点身份" in qml
    assert "匹配条件" in qml
    assert "property bool expanded: false" in qml
    assert "maximumLineCount: conditionItem.expanded ? 0 : 1" in qml
    assert "conditionItem.expanded ? \"收起\" : \"展开\"" in qml
    assert "命中记录" in qml
    assert '"调用 #"' in qml
    assert "id: hitRecordScroll" in qml
    assert "contentHeight: hitRecordColumn.implicitHeight + 24" in qml
    assert "width: hitRecordColumn.width" in qml
    assert "statusText" in qml
    assert "原始 JSON" in qml


def test_shared_controls_are_flat_and_json_viewer_is_wrapped():
    button = (QML_ROOT / "components" / "MbButton.qml").read_text(encoding="utf-8")
    viewer = (QML_ROOT / "components" / "MbJsonViewer.qml").read_text(encoding="utf-8")
    dialog = (QML_ROOT / "components" / "ConfirmDialog.qml").read_text(encoding="utf-8")

    assert "function foregroundColor" in button
    assert "function iconBackgroundColor" in button
    assert "variant === \"primary\") return appTheme.primarySoft" in button
    assert "implicitHeight: 36" in button
    assert "width: 20" in button
    assert "anchors.centerIn: parent" in button
    assert "Canvas {" in button
    assert "ctx.arc" in button
    assert 'text: "JSON"' in viewer
    assert "wrapMode: TextEdit.Wrap" in viewer
    assert "font.pixelSize: 12" in viewer
    assert "function ask" in dialog
    assert "confirmAction" in dialog


def test_destructive_actions_use_confirmation_dialog():
    checked_files = [
        "Main.qml",
        "CallRecordPage.qml",
        "BreakpointPage.qml",
        "SessionTab.qml",
        "BreakpointTab.qml",
        "InterfaceTab.qml",
    ]
    qml_text = "\n".join((QML_ROOT / name).read_text(encoding="utf-8") for name in checked_files)

    assert qml_text.count("ConfirmDialog") >= len(checked_files)
    assert "confirmDialog.ask" in qml_text
    assert "onClicked: bridge.clearCalls()" not in qml_text
    assert "onClicked: bridge.clearSessions()" not in qml_text
    assert "onClicked: bridge.deleteSession(" not in qml_text
    assert "onClicked: bridge.deleteBreakpoint(" not in qml_text


def test_right_detail_scrollbars_are_hidden():
    call_page = (QML_ROOT / "CallRecordPage.qml").read_text(encoding="utf-8")
    interface_page = (QML_ROOT / "InterfacePage.qml").read_text(encoding="utf-8")
    breakpoint_page = (QML_ROOT / "BreakpointPage.qml").read_text(encoding="utf-8")
    detail_panel = (QML_ROOT / "DetailPanel.qml").read_text(encoding="utf-8")
    viewer = (QML_ROOT / "components" / "MbJsonViewer.qml").read_text(encoding="utf-8")

    assert "ScrollBar.vertical: ScrollBar {\n                            policy: ScrollBar.AlwaysOff" in call_page
    assert interface_page.count("ScrollBar.vertical.policy: ScrollBar.AlwaysOff") >= 2
    assert breakpoint_page.count("ScrollBar.vertical.policy: ScrollBar.AlwaysOff") >= 3
    assert detail_panel.count("policy: ScrollBar.AlwaysOff") >= 2
    assert viewer.count("policy: ScrollBar.AsNeeded") >= 2


def test_main_has_paused_request_banner():
    qml = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert 'stateData.state === "DEBUGGING_PAUSED"' in qml
    assert "个请求命中断点并暂停" in qml
    assert "selectedCallIsPaused" in qml
    assert "继续单个" in qml
    assert "bridge.continueCall(root.selectedCallId)" in qml
    assert "bridge.continueAll()" in qml


def test_main_has_persistent_interface_lock_switch():
    qml = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "interfaceLocked" in qml
    assert "锁定接口" in qml
    assert "bridge.setInterfaceLocked(value)" in qml
    assert "MbSwitch" in qml


def test_main_uses_fixed_business_pages_and_title():
    qml = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert 'title: "组件化断点调试工具"' in qml
    assert "property int currentPage: 0" in qml
    assert 'text: "接口列表"' in qml
    assert 'text: "断点列表"' in qml
    assert 'text: "调用记录"' in qml
    assert 'text: "历史会话"' in qml
    assert "SettingsTab" not in qml
    assert "确认清空当前会话的数据吗？该操作会删除当前会话的接口、调用记录和相关断点。" in qml


def test_session_tab_exposes_mbrec_import_export_controls():
    qml = (QML_ROOT / "SessionTab.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")
    bridge_source = (QML_ROOT.parent / "bridge.py").read_text(encoding="utf-8")

    assert "导入 .mbrec" in qml
    assert "导出 .mbrec" in qml
    assert "导入后锁定接口" in qml
    assert "function stripMbrecSuffix" in qml
    assert "function sessionDisplayName" in qml
    assert "text: page.sessionDisplayName(modelData)" in qml
    assert "SessionId: " in qml
    assert 'text: page.isImportedSession(modelData) ? "导入" : "本地"' in qml
    assert "item.archive_id || item.archiveId" not in qml
    assert "item.import_file_name || item.importFileName || item.imported_at || item.importedAt" in qml
    assert "function requestImport" in qml
    assert "当前正在调试" in qml
    assert "暂停中的 Java 调用" in qml
    assert "onImportDuplicate" in qml
    assert "该 Session 已存在，不能重复导入。" in qml
    assert "duplicateImportFileName" in qml
    assert "bridge.openExistingSession(sessionId)" in qml
    assert "bridge.importSession(page.importLockInterfaces)" in qml
    assert "bridge.exportSession(page.exportSessionId, page.exportArchiveName, page.exportRemark)" in qml
    assert "/api/sessions/import-file" in bridge_source
    assert "/api/sessions/{sessionId}/export-file" in bridge_source
    assert "debugging: !!stateData.debugging" in main
    assert "pausedCount: Number(stateData.pausedCount || 0)" in main


def test_main_restores_operation_log_panel():
    qml = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "property bool logExpanded" in qml
    assert "function logSummary" in qml
    assert "root.logSummary()" in qml
    assert 'text: root.logExpanded ? "收起" : "展开"' in qml
    assert "TextArea {" in qml
    assert "text: root.resultText" in qml
    assert "selectByMouse: true" in qml


class CaptureBridge(Bridge):
    def __init__(self):
        super().__init__()
        self.requests = []
        self.refreshed = 0

    def _request(self, method, url, **kwargs):
        self.requests.append((method, url, kwargs))
        return {"success": True}

    def _emit_result(self, value):
        pass

    def refreshAll(self):
        self.refreshed += 1


def test_breakpoint_creation_uses_explicit_match_modes():
    bridge = CaptureBridge()

    bridge.createBreakpointFromInterface("if-1")
    bridge.createMethodBreakpointFromCall("call-1")
    bridge.createBreakpointFromCall("call-2")

    assert bridge.requests[0][2]["json"]["matchMode"] == "command_only"
    assert bridge.requests[1][2]["json"]["matchMode"] == "command_only"
    assert bridge.requests[2][2]["json"]["matchMode"] == "params_snapshot"
    assert all("selectedArgs" not in call[2]["json"] for call in bridge.requests)
    assert bridge.refreshed == 3


def test_bridge_emits_user_notice_for_duplicate_and_condition_breakpoints():
    bridge = Bridge()
    notices = []
    bridge.userNotice.connect(notices.append)

    bridge._emit_result({
        "success": False,
        "code": "DUPLICATE_COMMAND_BREAKPOINT",
        "message": "该命令断点已存在，请勿重复创建。",
    })
    bridge._emit_result({
        "success": True,
        "message": "条件断点已创建，已自动停用对应命令断点。",
    })

    assert notices == ["该命令断点已存在，请勿重复创建。", "条件断点已创建，已自动停用对应命令断点。"]


def test_clear_sessions_calls_backend_endpoint():
    bridge = CaptureBridge()

    bridge.clearSessions()

    assert bridge.requests == [("DELETE", f"{bridge.backend}/api/sessions", {})]
    assert bridge.refreshed == 1


def test_bridge_wires_interface_lock_and_manual_registration():
    bridge = CaptureBridge()

    bridge.setInterfaceLocked(True)
    bridge.addInterfaceFromCall("call-1")

    assert bridge.requests[0] == ("POST", f"{bridge.backend}/api/interfaces/lock", {"json": {"locked": True}})
    assert bridge.requests[1] == ("POST", f"{bridge.backend}/api/calls/call-1/interface", {})
    assert bridge.refreshed == 2


def test_bridge_emits_duplicate_import_and_can_open_existing_session():
    bridge = CaptureBridge()
    duplicates = []
    bridge.importDuplicate.connect(duplicates.append)

    bridge._handle_import_result({
        "success": False,
        "openExisting": True,
        "existingSessionId": "session-existing",
        "archiveName": "existing archive",
        "importFileName": "Existing.MBREC",
    })
    bridge.openExistingSession("session-existing")

    assert len(duplicates) == 1
    assert "session-existing" in duplicates[0]
    assert "existing archive" in duplicates[0]
    assert "Existing.MBREC" in duplicates[0]
    assert bridge.requests == [("POST", f"{bridge.backend}/api/sessions/session-existing/select", {})]
    assert bridge.refreshed == 1
