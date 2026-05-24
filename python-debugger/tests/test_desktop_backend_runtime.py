import sqlite3

import requests

from desktop.backend_runtime import DesktopBackendRuntime


def test_desktop_backend_runtime_starts_and_stops(tmp_path):
    runtime = DesktopBackendRuntime(port=5051, app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    assert runtime.start(timeout=3.0) is True
    assert runtime.owned is True
    assert runtime.is_ready() is True
    runtime.stop()
    assert runtime.owned is False


def test_desktop_backend_runtime_stops_active_debug_session(tmp_path):
    db_path = tmp_path / "debugger.sqlite3"
    runtime = DesktopBackendRuntime(port=5053, app_config={"TESTING": True, "DATABASE": str(db_path)})
    assert runtime.start(timeout=3.0) is True
    try:
        response = requests.post(f"{runtime.url}/api/debug/start", json={}, timeout=3)
        assert response.json()["debugging"] is True
    finally:
        runtime.stop()

    with sqlite3.connect(db_path) as db:
        row = db.execute("SELECT mode, status, debugging, end_time FROM debug_session").fetchone()

    assert row[0] == "idle"
    assert row[1] == "idle"
    assert row[2] == 0
    assert row[3]
