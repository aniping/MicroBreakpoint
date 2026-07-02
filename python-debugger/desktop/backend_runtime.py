import logging
import os
from pathlib import Path
import subprocess
import sys
from threading import Thread
from time import monotonic, sleep

import requests

from desktop.app_settings import backend_server_settings, ensure_settings_file, settings_path
from desktop.config import BACKEND_HOST, BACKEND_PORT


class DesktopBackendRuntime:
    BACKEND_MODES = {"internal", "jar", "external"}

    def __init__(self, host=None, port=BACKEND_PORT, app_config=None,
            backend_mode="internal", backend_jar=None, backend_dir=None):
        self.port = port
        self.app_config = app_config
        self.host = str(host or self._configured_host()).strip() or BACKEND_HOST
        self.url = f"http://{self._connect_host()}:{port}"
        if backend_mode not in self.BACKEND_MODES:
            raise ValueError(f"Unsupported backend mode: {backend_mode}")
        self.backend_mode = backend_mode
        self.backend_jar = backend_jar
        self.backend_dir = backend_dir
        self._process = None
        self._server = None
        self._thread = None
        self._owned = False

    @property
    def owned(self):
        return self._owned

    def start(self, timeout=8.0):
        self._enable_console_logging()
        if self.backend_mode == "external":
            self._log(f"skip backend startup at {self.url}")
            return False
        if self.is_ready():
            self._log(f"reuse backend at {self.url}")
            return False
        self._log(f"start {self.backend_mode} backend at {self.url}")
        if self.backend_mode == "internal":
            self._start_internal_backend()
        else:
            command = self._backend_command()
            self._process = subprocess.Popen(
                command,
                cwd=Path(command[-1]).parent,
                env=self._backend_env(),
                creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
            )
        self._owned = True
        try:
            self._wait_until_ready(timeout)
        except Exception:
            self._terminate_owned_backend()
            self._owned = False
            raise
        self._log(f"{self.backend_mode} backend ready at {self.url}")
        return True

    def stop(self):
        if self.backend_mode != "external":
            self._stop_debug_session()
        if not self._owned:
            return
        self._log(f"stop {self.backend_mode} backend at {self.url}")
        self._terminate_owned_backend()
        self._owned = False
        self._log(f"{self.backend_mode} backend stopped")

    def _terminate_owned_backend(self):
        if self._server is not None:
            self._shutdown_internal_backend()
            return
        self._terminate_process()

    def _terminate_process(self):
        if self._process is None:
            return
        self._process.terminate()
        try:
            self._process.wait(timeout=8)
        except subprocess.TimeoutExpired:
            self._process.kill()
            self._process.wait(timeout=3)
        self._process = None

    def _enable_console_logging(self):
        logger = logging.getLogger("werkzeug")
        logger.setLevel(logging.INFO)
        if not logger.handlers:
            handler = logging.StreamHandler()
            handler.setFormatter(logging.Formatter("%(message)s"))
            logger.addHandler(handler)

    def _log(self, message):
        print(f"[MicroBreakpoint] {message}", flush=True)

    def _backend_command(self):
        ensure_settings_file(self._settings_path())
        return [
            "java",
            f"-Dmicro-breakpoint.settings-file={self._settings_path()}",
            "-jar",
            str(self._resolve_backend_jar()),
        ]

    def _start_internal_backend(self):
        from app import create_app
        from werkzeug.serving import make_server

        app = create_app(self._internal_app_config())
        self._server = make_server(self.host, self.port, app, threaded=True)
        self._thread = Thread(target=self._server.serve_forever, daemon=True)
        self._thread.start()

    def _shutdown_internal_backend(self):
        self._server.shutdown()
        if self._thread is not None:
            self._thread.join(timeout=8)
        self._server = None
        self._thread = None

    def _internal_app_config(self):
        config = dict(self.app_config or {})
        config.setdefault("DATABASE", self._database_path())
        config.setdefault("SETTINGS_FILE", self._settings_path())
        return config

    def _resolve_backend_jar(self):
        explicit_jar = self.backend_jar or os.environ.get("MICRO_BREAKPOINT_BACKEND_JAR")
        if explicit_jar:
            jar = Path(explicit_jar).expanduser().resolve()
            if not jar.is_file():
                raise RuntimeError(f"Backend jar not found: {jar}")
            return jar

        backend_dir = self._resolve_backend_dir()
        preferred = backend_dir / "micro-breakpoint-debugger.jar"
        if preferred.is_file():
            return preferred.resolve()

        jars = sorted(path.resolve() for path in backend_dir.glob("micro-breakpoint-debugger-*.jar") if path.is_file())
        if len(jars) == 1:
            return jars[0]
        if len(jars) > 1:
            raise RuntimeError(
                f"Multiple backend jars found in {backend_dir}. "
                "Use --backend-jar to choose one."
            )
        raise RuntimeError(
            f"Backend jar not found in {backend_dir}. "
            "Put micro-breakpoint-debugger.jar there or use --backend-jar."
        )

    def _resolve_backend_dir(self):
        configured_dir = self.backend_dir or os.environ.get("MICRO_BREAKPOINT_BACKEND_DIR")
        if configured_dir:
            return Path(configured_dir).expanduser().resolve()
        return (self._app_base_dir() / "backend").resolve()

    def _backend_env(self):
        env = os.environ.copy()
        env["SERVER_ADDRESS"] = self.host
        env["SERVER_PORT"] = str(self.port)
        env["MICRO_BREAKPOINT_HOST"] = self.host
        env["MICRO_BREAKPOINT_PARENT_PID"] = str(os.getpid())
        env["MICRO_BREAKPOINT_DATABASE"] = self._database_path()
        payload_root = (self.app_config or {}).get("PAYLOAD_ROOT")
        if payload_root:
            env["MICRO_BREAKPOINT_PAYLOAD_ROOT"] = str(payload_root)
        return env

    def _database_path(self):
        database = (self.app_config or {}).get("DATABASE")
        if database:
            return str(database)
        return str((self._app_base_dir() / "data" / "debugger.sqlite3").resolve())

    def _settings_path(self):
        configured = (self.app_config or {}).get("SETTINGS_FILE")
        if configured:
            return str(Path(configured).expanduser().resolve())
        return str(settings_path(self._app_base_dir()))

    def _configured_host(self):
        return backend_server_settings(self._settings_path()).get("host", BACKEND_HOST)

    def _connect_host(self):
        if self.host in ("0.0.0.0", "::"):
            return BACKEND_HOST
        return self.host

    def _app_base_dir(self):
        if getattr(sys, "frozen", False):
            return Path(sys.executable).resolve().parent
        return Path(__file__).resolve().parents[1]

    def _stop_debug_session(self):
        try:
            requests.post(f"{self.url}/api/debug/stop", timeout=1.0)
        except requests.RequestException:
            pass

    def is_ready(self):
        try:
            response = requests.get(f"{self.url}/api/debug/state", timeout=0.5)
            return response.ok
        except requests.RequestException:
            return False

    def _wait_until_ready(self, timeout):
        deadline = monotonic() + timeout
        while monotonic() < deadline:
            if self.is_ready():
                return
            sleep(0.1)
        raise RuntimeError(f"{self.backend_mode} backend did not start at {self.url}")
