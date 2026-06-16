import os

from app import create_app
from desktop.config import BACKEND_HOST, BACKEND_PORT


def app_config_from_env():
    config = {}
    database = os.environ.get("MICRO_BREAKPOINT_DATABASE")
    if database:
        config["DATABASE"] = database
    payload_root = os.environ.get("MICRO_BREAKPOINT_PAYLOAD_ROOT")
    if payload_root:
        config["PAYLOAD_ROOT"] = payload_root
    return config or None


app = create_app(app_config_from_env())

if __name__ == "__main__":
    host = os.environ.get("MICRO_BREAKPOINT_HOST", BACKEND_HOST)
    port = int(os.environ.get("SERVER_PORT", BACKEND_PORT))
    app.run(host=host, port=port, threaded=True)
