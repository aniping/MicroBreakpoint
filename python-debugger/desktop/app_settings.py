import json
import sys
from copy import deepcopy
from pathlib import Path

from desktop.config import BACKEND_HOST


DEFAULT_SETTINGS = {
    "themeMode": "dark",
    "server": {
        "host": BACKEND_HOST,
    },
    "debugTarget": {
        "host": "127.0.0.1",
        "port": 8080,
        "debuggerSwitchPath": "/api/demo/debugger/enabled",
        "requestTimeoutMs": 1000,
    },
}


def app_base_dir():
    if getattr(sys, "frozen", False):
        return Path(sys.executable).resolve().parent
    return Path(__file__).resolve().parents[1]


def settings_path(base_dir=None):
    base = Path(base_dir) if base_dir is not None else app_base_dir()
    return (base / "data" / "settings.json").resolve()


def load_settings(path=None):
    file_path = Path(path) if path else settings_path()
    try:
        with file_path.open("r", encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, ValueError, TypeError):
        data = {}
    return normalize_settings(data)


def save_settings(data, path=None):
    file_path = Path(path) if path else settings_path()
    settings = normalize_settings(data)
    file_path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = file_path.with_name(file_path.name + ".tmp")
    with temp_path.open("w", encoding="utf-8") as handle:
        json.dump(settings, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    temp_path.replace(file_path)
    return settings


def ensure_settings_file(path=None):
    file_path = Path(path) if path else settings_path()
    if not file_path.exists():
        return save_settings(DEFAULT_SETTINGS, file_path)
    return load_settings(file_path)


def normalize_settings(data):
    settings = deepcopy(DEFAULT_SETTINGS)
    if not isinstance(data, dict):
        return settings

    theme_mode = data.get("themeMode")
    if theme_mode in ("light", "dark"):
        settings["themeMode"] = theme_mode

    server = data.get("server")
    if isinstance(server, dict):
        settings["server"] = _normalize_server(server)

    target = data.get("debugTarget")
    if isinstance(target, dict):
        settings["debugTarget"] = _normalize_debug_target(target)
    return settings


def _normalize_server(server):
    defaults = DEFAULT_SETTINGS["server"]
    host = str(server.get("host") or defaults["host"]).strip() or defaults["host"]
    return {"host": host}


def _normalize_debug_target(target):
    defaults = DEFAULT_SETTINGS["debugTarget"]
    host = str(target.get("host") or defaults["host"]).strip() or defaults["host"]
    path = str(target.get("debuggerSwitchPath") or defaults["debuggerSwitchPath"]).strip()
    if not path:
        path = defaults["debuggerSwitchPath"]
    if not path.startswith("/"):
        path = "/" + path
    return {
        "host": host,
        "port": _int_in_range(target.get("port"), defaults["port"], 1, 65535),
        "debuggerSwitchPath": path,
        "requestTimeoutMs": _int_in_range(
            target.get("requestTimeoutMs"),
            defaults["requestTimeoutMs"],
            1,
            600000,
        ),
    }


def debug_target_settings(path=None):
    return load_settings(path)["debugTarget"]


def backend_server_settings(path=None):
    return load_settings(path)["server"]


def build_debug_switch_url(target):
    normalized = _normalize_debug_target(target or {})
    host = normalized["host"].rstrip("/")
    if "://" in host:
        base_url = host
    else:
        base_url = f"http://{host}:{normalized['port']}"
    return base_url.rstrip("/") + normalized["debuggerSwitchPath"]


def _int_in_range(value, default, minimum, maximum):
    try:
        parsed = int(value)
    except (TypeError, ValueError):
        return default
    if parsed < minimum or parsed > maximum:
        return default
    return parsed
