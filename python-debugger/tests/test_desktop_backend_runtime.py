import os
import socket
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread

import pytest
import requests

import desktop.backend_runtime as backend_runtime
from desktop.backend_runtime import DesktopBackendRuntime
from run_desktop import parse_args


def test_desktop_backend_runtime_defaults_to_internal():
    runtime = DesktopBackendRuntime(port=free_port())

    assert runtime.backend_mode == "internal"


def test_run_desktop_cli_defaults_to_internal():
    args = parse_args([])

    assert args.backend == "internal"
    assert args.backend_jar is None
    assert args.backend_dir is None


def test_run_desktop_cli_accepts_backend_modes():
    assert parse_args(["--backend", "internal"]).backend == "internal"
    assert parse_args(["--backend", "jar"]).backend == "jar"
    assert parse_args(["--backend", "external"]).backend == "external"


def test_run_desktop_cli_accepts_jar_options():
    args = parse_args(["--backend", "jar", "--backend-jar", "app.jar", "--backend-dir", "backend"])

    assert args.backend == "jar"
    assert args.backend_jar == "app.jar"
    assert args.backend_dir == "backend"


def test_external_backend_runtime_skips_readiness_and_shutdown(monkeypatch):
    runtime = DesktopBackendRuntime(port=free_port(), backend_mode="external")

    monkeypatch.setattr(runtime, "is_ready", pytest.fail)
    monkeypatch.setattr(runtime, "_stop_debug_session", pytest.fail)
    monkeypatch.setattr(
        backend_runtime.subprocess,
        "Popen",
        lambda *args, **kwargs: pytest.fail("Popen should not be called"),
    )

    assert runtime.start(timeout=0.1) is False
    runtime.stop()
    assert runtime.owned is False


def test_internal_backend_runtime_starts_flask_backend_and_stops_owned_server(tmp_path, monkeypatch):
    started = {"called": False}
    stopped = {"called": False}

    def fake_start():
        started["called"] = True
        runtime._server = object()

    def fake_stop():
        stopped["called"] = True
        runtime._server = None

    runtime = DesktopBackendRuntime(
        port=free_port(),
        app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")},
        backend_mode="internal",
    )
    ready = [False, True]
    monkeypatch.setattr(runtime, "is_ready", lambda: ready.pop(0))
    monkeypatch.setattr(runtime, "_start_internal_backend", fake_start)
    monkeypatch.setattr(runtime, "_shutdown_internal_backend", fake_stop)
    monkeypatch.setattr(
        backend_runtime.subprocess,
        "Popen",
        lambda *args, **kwargs: pytest.fail("Popen should not be called"),
    )

    assert runtime.start(timeout=1.0) is True
    assert runtime.owned is True
    assert started["called"] is True
    assert runtime._process is None

    runtime.stop()
    assert stopped["called"] is True
    assert runtime.owned is False


def test_internal_backend_runtime_uses_default_python_debugger_database():
    runtime = DesktopBackendRuntime(port=free_port(), backend_mode="internal")

    config = runtime._internal_app_config()

    expected = os.path.join("python-debugger", "data", "debugger.sqlite3")
    assert config["DATABASE"].endswith(expected)


def test_internal_backend_runtime_serves_flask_app(tmp_path):
    runtime = DesktopBackendRuntime(
        port=free_port(),
        app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")},
        backend_mode="internal",
    )
    try:
        assert runtime.start(timeout=10.0) is True
        response = requests.get(f"{runtime.url}/api/debug/state", timeout=3)
        assert response.status_code == 200
        assert response.json()["success"] is True
    finally:
        runtime.stop()


def test_internal_backend_runtime_reuses_ready_backend_and_stops_debug_session():
    server, state = start_backend_state_server()
    runtime = DesktopBackendRuntime(port=server.server_port, backend_mode="internal")
    try:
        assert runtime.start(timeout=1.0) is False
        assert runtime.owned is False
        runtime.stop()
        assert state["stop_called"] is True
    finally:
        server.shutdown()
        server.server_close()


def test_jar_backend_runtime_starts_resolved_jar_and_stops_owned_process(tmp_path, monkeypatch):
    jar = tmp_path / "backend" / "micro-breakpoint-debugger.jar"
    jar.parent.mkdir()
    jar.write_text("", encoding="utf-8")
    process = FakeProcess()
    started = {}

    def fake_popen(command, cwd, env, creationflags):
        started["command"] = command
        started["cwd"] = cwd
        started["env"] = env
        started["creationflags"] = creationflags
        return process

    runtime = DesktopBackendRuntime(
        port=free_port(),
        app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")},
        backend_mode="jar",
        backend_jar=jar,
    )
    ready = [False, True]
    monkeypatch.setattr(runtime, "is_ready", lambda: ready.pop(0))
    monkeypatch.setattr(backend_runtime.subprocess, "Popen", fake_popen)

    assert runtime.start(timeout=1.0) is True
    assert runtime.owned is True
    assert started["command"] == ["java", "-jar", str(jar.resolve())]
    assert started["cwd"] == jar.parent.resolve()
    assert started["env"]["SERVER_PORT"] == str(runtime.port)
    assert started["env"]["MICRO_BREAKPOINT_PARENT_PID"] == str(os.getpid())

    runtime.stop()
    assert process.terminated is True
    assert runtime.owned is False


def test_jar_backend_runtime_prints_console_lifecycle_logs(tmp_path, monkeypatch, capsys):
    jar = tmp_path / "micro-breakpoint-debugger.jar"
    jar.write_text("", encoding="utf-8")
    runtime = DesktopBackendRuntime(port=free_port(), backend_mode="jar", backend_jar=jar)
    ready = [False, True]
    monkeypatch.setattr(runtime, "is_ready", lambda: ready.pop(0))
    monkeypatch.setattr(backend_runtime.subprocess, "Popen", lambda *args, **kwargs: FakeProcess())

    assert runtime.start(timeout=1.0) is True
    runtime.stop()

    output = capsys.readouterr().out
    assert "[MicroBreakpoint] start jar backend at" in output
    assert "[MicroBreakpoint] jar backend ready at" in output
    assert "[MicroBreakpoint] stop jar backend at" in output
    assert "[MicroBreakpoint] jar backend stopped" in output


def test_desktop_backend_runtime_passes_parent_pid_to_java(tmp_path):
    runtime = DesktopBackendRuntime(port=free_port(), app_config={"TESTING": True, "DATABASE": str(tmp_path / "debugger.sqlite3")})

    env = runtime._backend_env()

    assert env["MICRO_BREAKPOINT_PARENT_PID"] == str(os.getpid())


def test_backend_command_uses_default_named_jar(tmp_path, monkeypatch):
    backend_dir = tmp_path / "backend"
    jar = backend_dir / "micro-breakpoint-debugger.jar"
    backend_dir.mkdir()
    jar.write_text("", encoding="utf-8")
    monkeypatch.chdir(tmp_path)
    runtime = DesktopBackendRuntime(backend_mode="jar")

    assert runtime._backend_command() == ["java", "-jar", str(jar.resolve())]


def test_backend_command_uses_single_versioned_jar(tmp_path):
    backend_dir = tmp_path / "backend"
    jar = backend_dir / "micro-breakpoint-debugger-0.1.0.jar"
    backend_dir.mkdir()
    jar.write_text("", encoding="utf-8")
    runtime = DesktopBackendRuntime(backend_mode="jar", backend_dir=backend_dir)

    assert runtime._backend_command() == ["java", "-jar", str(jar.resolve())]


def test_backend_command_uses_explicit_jar_before_backend_dir(tmp_path):
    explicit = tmp_path / "chosen.jar"
    explicit.write_text("", encoding="utf-8")
    backend_dir = tmp_path / "backend"
    backend_dir.mkdir()
    (backend_dir / "micro-breakpoint-debugger.jar").write_text("", encoding="utf-8")
    runtime = DesktopBackendRuntime(backend_mode="jar", backend_jar=explicit, backend_dir=backend_dir)

    assert runtime._backend_command() == ["java", "-jar", str(explicit.resolve())]


def test_backend_command_uses_environment_jar(tmp_path, monkeypatch):
    jar = tmp_path / "env.jar"
    jar.write_text("", encoding="utf-8")
    monkeypatch.setenv("MICRO_BREAKPOINT_BACKEND_JAR", str(jar))
    runtime = DesktopBackendRuntime(backend_mode="jar")

    assert runtime._backend_command() == ["java", "-jar", str(jar.resolve())]


def test_backend_command_fails_when_jar_is_missing(tmp_path):
    runtime = DesktopBackendRuntime(backend_mode="jar", backend_dir=tmp_path)

    with pytest.raises(RuntimeError, match="Backend jar not found"):
        runtime._backend_command()


def test_backend_command_fails_when_multiple_versioned_jars_exist(tmp_path):
    (tmp_path / "micro-breakpoint-debugger-0.1.0.jar").write_text("", encoding="utf-8")
    (tmp_path / "micro-breakpoint-debugger-0.2.0.jar").write_text("", encoding="utf-8")
    runtime = DesktopBackendRuntime(backend_mode="jar", backend_dir=tmp_path)

    with pytest.raises(RuntimeError, match="Multiple backend jars"):
        runtime._backend_command()


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


class FakeProcess:
    def __init__(self):
        self.terminated = False
        self.killed = False

    def terminate(self):
        self.terminated = True

    def wait(self, timeout):
        return 0

    def kill(self):
        self.killed = True


def start_backend_state_server():
    state = {"stop_called": False}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path != "/api/debug/state":
                self.send_response(404)
                self.end_headers()
                return
            payload = b'{"debugging":false}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json;charset=UTF-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def do_POST(self):
            if self.path != "/api/debug/stop":
                self.send_response(404)
                self.end_headers()
                return
            state["stop_called"] = True
            payload = b'{"success":true}'
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
