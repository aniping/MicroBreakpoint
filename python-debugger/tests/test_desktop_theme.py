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
