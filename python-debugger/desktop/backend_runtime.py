import logging
import os
from pathlib import Path
import shutil
import subprocess
from time import monotonic, sleep

import requests

from desktop.config import BACKEND_HOST, BACKEND_PORT


class DesktopBackendRuntime:
    def __init__(self, host=BACKEND_HOST, port=BACKEND_PORT, app_config=None, command=None):
        self.host = host
        self.port = port
        self.app_config = app_config
        self.url = f"http://{host}:{port}"
        self.command = command
        self._process = None
        self._owned = False

    @property
    def owned(self):
        return self._owned

    def start(self, timeout=8.0):
        self._enable_console_logging()
        if self.is_ready():
            self._log(f"reuse Java backend at {self.url}")
            return False
        self._log(f"start Java backend at {self.url}")
        self._process = subprocess.Popen(
            self.command or self._backend_command(),
            cwd=self._java_backend_dir(),
            env=self._backend_env(),
            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
        )
        self._owned = True
        try:
            self._wait_until_ready(timeout)
        except Exception:
            self._terminate_process()
            self._owned = False
            raise
        self._log(f"Java backend ready at {self.url}")
        return True

    def stop(self):
        self._stop_debug_session()
        if not self._owned or self._process is None:
            return
        self._log(f"stop Java backend at {self.url}")
        self._terminate_process()
        self._owned = False
        self._log("Java backend stopped")

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

    def _java_backend_dir(self):
        return Path(__file__).resolve().parents[2] / "java-debugger"

    def _backend_command(self):
        jar = self._java_backend_dir() / "target" / "micro-breakpoint-debugger-0.1.0.jar"
        if jar.exists():
            return ["java", "-jar", str(jar)]
        mvn = shutil.which("mvn.cmd") or shutil.which("mvn") or "mvn"
        return [mvn, "-q", "-DskipTests", "spring-boot:run"]

    def _backend_env(self):
        env = os.environ.copy()
        env["SERVER_PORT"] = str(self.port)
        env["MICRO_BREAKPOINT_DATABASE"] = self._database_path()
        payload_root = (self.app_config or {}).get("PAYLOAD_ROOT")
        if payload_root:
            env["MICRO_BREAKPOINT_PAYLOAD_ROOT"] = str(payload_root)
        demo_base_url = (self.app_config or {}).get("DEMO_BASE_URL")
        if demo_base_url:
            env["MICRO_BREAKPOINT_DEMO_BASE_URL"] = str(demo_base_url)
        demo_request_timeout_ms = (self.app_config or {}).get("DEMO_REQUEST_TIMEOUT_MS")
        if demo_request_timeout_ms:
            env["MICRO_BREAKPOINT_DEMO_REQUEST_TIMEOUT_MS"] = str(demo_request_timeout_ms)
        return env

    def _database_path(self):
        database = (self.app_config or {}).get("DATABASE")
        if database:
            return str(database)
        return str((Path(__file__).resolve().parents[1] / "data" / "debugger.sqlite3").resolve())

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
        raise RuntimeError(f"Java backend did not start at {self.url}")
