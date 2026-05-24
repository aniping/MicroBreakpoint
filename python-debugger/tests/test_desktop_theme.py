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
    qml = (QML_ROOT / "CallRecordTab.qml").read_text(encoding="utf-8")

    assert "item.interface_alias" in qml


def test_call_record_uses_business_debug_fields():
    qml = (QML_ROOT / "CallRecordPage.qml").read_text(encoding="utf-8")

    assert "object_name" in qml
    assert "cmd_name" in qml
    assert "params_summary" in qml
    assert "objectName(item)" in qml
    assert "cmdName(item)" in qml


def test_call_record_page_keeps_filters_inside_groups():
    qml = (QML_ROOT / "CallRecordPage.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "CallRecordPage" in main
    assert "搜索 \" + modelData.objectName + \" 内调用" in qml
    assert "HeaderCell { tableWidth: tableFlick.width; groupName: modelData.objectName" in qml
    assert "function setColumnWidth" in qml
    assert "function isResizableColumn" in qml
    assert "index === 2 || index === 4 || index === 6 || index === 7 || index === 8" in qml
    assert "function setSort" in qml
    assert "function pagedRows" not in qml
    assert "Flickable {" in qml
    assert "flickableDirection: Flickable.HorizontalFlick" in qml
    assert "interactive: false" in qml
    assert "ScrollBar.vertical.policy" not in qml
    assert "onSelectedCallIdChanged: detailTabIndex = 0" in qml
    assert "当前分组显示" in qml


def test_interface_page_uses_grouped_cards_and_detail_tabs():
    qml = (QML_ROOT / "InterfacePage.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "InterfacePage" in main
    assert "搜索 \" + modelData.objectName + \" 内接口" in qml
    assert "全部展开" in qml
    assert "只看断点" in qml
    assert "查看样本" in qml
    assert "从该样本创建断点" in qml
    assert "别名" not in qml
    assert "component MetricCell" in qml
    assert "Layout.preferredWidth: 338" in qml
    assert "columns: 3" in qml
    assert "Layout.preferredWidth: 128" in qml
    assert qml.count('Layout.preferredHeight: 26') >= 4
    assert "MbDetailCard" in qml
    assert "接口身份" in qml
    assert "参数样本" in qml
    assert "相关调用" in qml
    assert '"调用 #"' in qml
    assert "id: relatedCallScroll" in qml
    assert "contentHeight: relatedCallColumn.implicitHeight + 24" in qml
    assert "width: relatedCallColumn.width" in qml
    assert "RelatedCell" not in qml
    assert "原始 JSON" in qml


def test_call_record_page_shows_breakpoint_list_in_detail_panel():
    qml = (QML_ROOT / "CallRecordPage.qml").read_text(encoding="utf-8")

    assert "断点列表 (\" + breakpoints.length + \")" in qml
    assert "当前 Session" in qml
    assert "page.breakpointTitle(modelData)" in qml
    assert "bridge.setBreakpointEnabled(modelData.id, value)" in qml


def test_breakpoint_page_uses_grouped_cards_filters_and_hit_jump():
    qml = (QML_ROOT / "BreakpointPage.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "BreakpointPage" in main
    assert "objectOptions" in qml
    assert "搜索断点 / 命令 / 槽位" in qml
    assert "function groups" in qml
    assert "命中范围" in qml
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

    assert "function foregroundColor" in button
    assert "variant === \"primary\") return appTheme.primarySoft" in button
    assert "implicitHeight: 36" in button
    assert 'text: "JSON"' in viewer
    assert "wrapMode: TextEdit.Wrap" in viewer
    assert "font.pixelSize: 12" in viewer


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
    assert viewer.count("policy: ScrollBar.AlwaysOff") >= 2


def test_main_has_paused_request_banner():
    qml = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert 'stateData.state === "DEBUGGING_PAUSED"' in qml
    assert "个请求命中断点并暂停" in qml
    assert "bridge.continueAll()" in qml


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
