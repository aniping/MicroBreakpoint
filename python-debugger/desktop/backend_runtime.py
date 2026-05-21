from threading import Thread
from time import monotonic, sleep

import requests
from werkzeug.serving import make_server

from app import create_app


class DesktopBackendRuntime:
    def __init__(self, host="127.0.0.1", port=5050):
        self.host = host
        self.port = port
        self.url = f"http://{host}:{port}"
        self._server = None
        self._thread = None
        self._owned = False

    @property
    def owned(self):
        return self._owned

    def start(self, timeout=8.0):
        if self.is_ready():
            return False
        app = create_app()
        self._server = make_server(self.host, self.port, app, threaded=True)
        self._thread = Thread(target=self._server.serve_forever, name="micro-breakpoint-backend", daemon=True)
        self._thread.start()
        self._owned = True
        self._wait_until_ready(timeout)
        return True

    def stop(self):
        if not self._owned or self._server is None:
            return
        self._server.shutdown()
        if self._thread is not None:
            self._thread.join(timeout=3)
        self._server = None
        self._thread = None
        self._owned = False

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
