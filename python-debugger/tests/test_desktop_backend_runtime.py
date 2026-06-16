import sqlite3
import socket
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread

import requests

from desktop.backend_runtime import DesktopBackendRuntime


def test_desktop_backend_runtime_starts_and_stops(tmp_path):
    runtime = DesktopBackendRuntime(port=free_port(), app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})
    assert runtime.start(timeout=10.0) is True
    assert runtime.owned is True
    assert runtime.is_ready() is True
    runtime.stop()
    assert runtime.owned is False


def test_desktop_backend_runtime_stops_active_debug_session(tmp_path):
    db_path = tmp_path / "debugger.sqlite3"
    demo_server, demo_state = start_demo_switch_server()
    demo_base_url = f"http://127.0.0.1:{demo_server.server_port}"
    runtime = DesktopBackendRuntime(port=free_port(), app_config={
        "TESTING": True,
        "DATABASE": str(db_path),
        "DEMO_BASE_URL": demo_base_url,
        "DEMO_REQUEST_TIMEOUT_MS": 200,
    })
    try:
        assert runtime.start(timeout=10.0) is True
        response = requests.post(f"{runtime.url}/api/debug/start", json={}, timeout=3)
        assert response.ok
        assert response.json()["debugging"] is True
        assert demo_state["enabled"] is True
    finally:
        runtime.stop()
        demo_server.shutdown()
        demo_server.server_close()

    with sqlite3.connect(db_path) as db:
        row = db.execute("SELECT mode, status, debugging, end_time FROM debug_session").fetchone()

    assert row[0] == "idle"
    assert row[1] == "idle"
    assert row[2] == 0
    assert row[3]


def test_desktop_backend_runtime_prints_console_lifecycle_logs(tmp_path, capsys):
    runtime = DesktopBackendRuntime(port=free_port(), app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})

    assert runtime.start(timeout=10.0) is True
    runtime.stop()

    output = capsys.readouterr().out
    assert "[MicroBreakpoint] start Java backend at" in output
    assert "[MicroBreakpoint] Java backend ready at" in output
    assert "[MicroBreakpoint] stop Java backend at" in output
    assert "[MicroBreakpoint] Java backend stopped" in output


def test_desktop_backend_runtime_passes_parent_pid_to_java(tmp_path):
    runtime = DesktopBackendRuntime(port=free_port(), app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})

    env = runtime._backend_env()

    assert env["MICRO_BREAKPOINT_PARENT_PID"] == str(os.getpid())


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def start_demo_switch_server():
    state = {"enabled": False}

    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path != "/api/demo/debugger/enabled":
                self.send_response(404)
                self.end_headers()
                return
            body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
            state["enabled"] = b'"enabled":true' in body.replace(b" ", b"")
            payload = (b'{"success":true,"enabled":' + str(state["enabled"]).lower().encode("ascii") + b"}")
            self.send_response(200)
            self.send_header("Content-Type", "application/json;charset=UTF-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format, *args):
            return

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server, state
