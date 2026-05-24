import logging
from threading import Thread
from time import monotonic, sleep

import requests
from werkzeug.serving import make_server

from app import create_app
from desktop.config import BACKEND_HOST, BACKEND_PORT


class DesktopBackendRuntime:
    def __init__(self, host=BACKEND_HOST, port=BACKEND_PORT, app_config=None):
        self.host = host
        self.port = port
        self.app_config = app_config
        self.url = f"http://{host}:{port}"
        self._server = None
        self._thread = None
        self._owned = False

    @property
    def owned(self):
        return self._owned

    def start(self, timeout=8.0):
        self._enable_console_logging()
        if self.is_ready():
            self._log(f"reuse Python backend at {self.url}")
            return False
        self._log(f"start Python backend at {self.url}")
        app = create_app(self.app_config)
        self._server = make_server(self.host, self.port, app, threaded=True)
        self._thread = Thread(target=self._server.serve_forever, name="micro-breakpoint-backend", daemon=True)
        self._thread.start()
        self._owned = True
        self._wait_until_ready(timeout)
        self._log(f"Python backend ready at {self.url}")
        return True

    def stop(self):
        self._stop_debug_session()
        if not self._owned or self._server is None:
            return
        self._log(f"stop Python backend at {self.url}")
        self._server.shutdown()
        if self._thread is not None:
            self._thread.join(timeout=3)
        self._server = None
        self._thread = None
        self._owned = False
        self._log("Python backend stopped")

    def _enable_console_logging(self):
        logger = logging.getLogger("werkzeug")
        logger.setLevel(logging.INFO)
        if not logger.handlers:
            handler = logging.StreamHandler()
            handler.setFormatter(logging.Formatter("%(message)s"))
            logger.addHandler(handler)

    def _log(self, message):
        print(f"[MicroBreakpoint] {message}", flush=True)

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
        raise RuntimeError(f"Python backend did not start at {self.url}")
