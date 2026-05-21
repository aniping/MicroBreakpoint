from desktop.bridge import Bridge


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
