import json

from desktop.app_settings import (
    backend_server_settings,
    build_debug_switch_url,
    ensure_settings_file,
    load_settings,
    save_settings,
)


def test_settings_file_is_created_with_defaults(tmp_path):
    settings_file = tmp_path / "data" / "settings.json"

    settings = ensure_settings_file(settings_file)

    assert settings["themeMode"] == "dark"
    assert settings["server"]["host"] == "127.0.0.1"
    assert settings["debugTarget"]["host"] == "127.0.0.1"
    assert settings_file.exists()


def test_settings_are_normalized_and_saved(tmp_path):
    settings_file = tmp_path / "settings.json"

    saved = save_settings({
        "themeMode": "light",
        "server": {
            "host": "192.168.1.20",
        },
        "debugTarget": {
            "host": "10.0.0.8",
            "port": "19090",
            "debuggerSwitchPath": "debugger/enabled",
            "requestTimeoutMs": "2500",
        },
    }, settings_file)

    assert saved["themeMode"] == "light"
    assert saved["server"] == {
        "host": "192.168.1.20",
    }
    assert saved["debugTarget"] == {
        "host": "10.0.0.8",
        "port": 19090,
        "debuggerSwitchPath": "/debugger/enabled",
        "requestTimeoutMs": 2500,
    }
    assert json.loads(settings_file.read_text(encoding="utf-8")) == saved
    assert load_settings(settings_file) == saved
    assert backend_server_settings(settings_file) == {"host": "192.168.1.20"}


def test_debug_switch_url_uses_host_port_and_path():
    url = build_debug_switch_url({
        "host": "192.168.1.9",
        "port": 18888,
        "debuggerSwitchPath": "api/debugger/enabled",
        "requestTimeoutMs": 1000,
    })

    assert url == "http://192.168.1.9:18888/api/debugger/enabled"
