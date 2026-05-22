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
    assert "HeaderCell { groupName: modelData.objectName" in qml
    assert "function setColumnWidth" in qml
    assert "function setSort" in qml
    assert "function pagedRows" in qml
    assert "当前分组显示" in qml


def test_interface_page_uses_grouped_cards_and_detail_tabs():
    qml = (QML_ROOT / "InterfacePage.qml").read_text(encoding="utf-8")
    main = (QML_ROOT / "Main.qml").read_text(encoding="utf-8")

    assert "InterfacePage" in main
    assert "搜索 \" + modelData.objectName + \" 内接口" in qml
    assert "全部展开" in qml
    assert "只看断点" in qml
    assert "编辑" in qml and "保存" in qml and "取消" in qml
    assert "接口概览" in qml
    assert "参数结构" in qml
    assert "样本参数" in qml
    assert "相关调用" in qml
    assert "原始 JSON" in qml


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
