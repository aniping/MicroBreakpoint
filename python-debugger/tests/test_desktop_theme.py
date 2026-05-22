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
    qml = (QML_ROOT / "CallRecordTab.qml").read_text(encoding="utf-8")

    assert "item.object_name" in qml
    assert "item.cmd_name" in qml
    assert "item.params_summary" in qml
    assert "modelData.object_name" in qml
    assert "modelData.cmd_name" in qml


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
