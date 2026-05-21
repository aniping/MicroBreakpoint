from desktop.backend_runtime import DesktopBackendRuntime


def test_desktop_backend_runtime_starts_and_stops(tmp_path):
    runtime = DesktopBackendRuntime(port=5051, app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    assert runtime.start(timeout=3.0) is True
    assert runtime.owned is True
    assert runtime.is_ready() is True
    runtime.stop()
    assert runtime.owned is False
